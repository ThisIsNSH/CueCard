use axum::{
    extract::Query,
    http::StatusCode,
    response::{Html, Json, Redirect},
    routing::{get, post},
    Router,
};
use base64::engine::general_purpose::{STANDARD, URL_SAFE_NO_PAD};
use base64::Engine;
use once_cell::sync::Lazy;
use parking_lot::RwLock;
use rand::{distributions::Alphanumeric, Rng};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use tauri::{async_runtime, AppHandle, Emitter, Manager};
use tauri_plugin_opener::OpenerExt;
use tauri_plugin_store::StoreExt;
use tower_http::{
    cors::{Any, CorsLayer},
    services::{ServeDir, ServeFile},
};

#[cfg(target_os = "macos")]
#[macro_use]
extern crate objc;

// OAuth2 Configuration
const GOOGLE_AUTH_URL: &str = "https://accounts.google.com/o/oauth2/v2/auth";
const GOOGLE_TOKEN_URL: &str = "https://oauth2.googleapis.com/token";
const REDIRECT_URI: &str = "http://127.0.0.1:3642/oauth/callback";
const SCOPE_SLIDES: &str = "https://www.googleapis.com/auth/presentations.readonly";
const SCOPE_PROFILE: &str = "openid email profile";
const FIREBASE_SIGN_IN_URL: &str = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp";
const FIREBASE_SIGN_UP_URL: &str = "https://identitytoolkit.googleapis.com/v1/accounts:signUp";
const FIREBASE_TOKEN_REFRESH_URL: &str = "https://securetoken.googleapis.com/v1/token";
const FIRESTORE_BASE_URL: &str = "https://firestore.googleapis.com/v1";

// Global state
static CURRENT_SLIDE: Lazy<Arc<RwLock<Option<SlideData>>>> =
    Lazy::new(|| Arc::new(RwLock::new(None)));
static SLIDE_NOTES: Lazy<Arc<RwLock<HashMap<String, String>>>> =
    Lazy::new(|| Arc::new(RwLock::new(HashMap::new())));
static CURRENT_PRESENTATION_ID: Lazy<Arc<RwLock<Option<String>>>> =
    Lazy::new(|| Arc::new(RwLock::new(None)));
static APP_HANDLE: Lazy<Arc<RwLock<Option<AppHandle>>>> =
    Lazy::new(|| Arc::new(RwLock::new(None)));
static OAUTH_TOKENS: Lazy<Arc<RwLock<Option<OAuthTokens>>>> =
    Lazy::new(|| Arc::new(RwLock::new(None)));
static PENDING_OAUTH_SCOPE: Lazy<Arc<RwLock<Option<String>>>> =
    Lazy::new(|| Arc::new(RwLock::new(None)));
static PKCE_CODE_VERIFIER: Lazy<Arc<RwLock<Option<String>>>> =
    Lazy::new(|| Arc::new(RwLock::new(None)));
static GOOGLE_OAUTH_CONFIG: Lazy<Arc<RwLock<Option<GoogleOAuthConfig>>>> =
    Lazy::new(|| Arc::new(RwLock::new(None)));
static FIREBASE_CONFIG: Lazy<FirebaseConfig> = Lazy::new(|| load_firebase_config());
static FIREBASE_SESSION: Lazy<Arc<RwLock<Option<FirebaseSession>>>> =
    Lazy::new(|| Arc::new(RwLock::new(None)));

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OAuthTokens {
    pub access_token: String,
    pub refresh_token: Option<String>,
    pub expires_at: Option<i64>,
    #[serde(default)]
    pub granted_scopes: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SlideData {
    pub presentation_id: String,
    pub slide_id: String,
    pub slide_number: i32,
    pub title: String,
    pub mode: String,
    pub timestamp: i64,
    pub url: String,
}

#[derive(Debug, Serialize)]
pub struct ApiResponse {
    received: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    notes: Option<String>,
}

#[derive(Debug, Serialize, Clone)]
pub struct SlideUpdateEvent {
    pub slide_data: SlideData,
    pub notes: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct OAuthCallback {
    code: Option<String>,
    error: Option<String>,
}

fn oauth_success_page() -> Html<String> {
    Html(
        r#"<!DOCTYPE html>
        <html><head><title>Authentication Successful</title>
        <style>
            body { font-family: system-ui; padding: 40px; text-align: center; background: #fff; }
            .success { color: #000; }
        </style>
        </head><body>
        <h1 class="success">Authentication Successful!</h1>
        <p>You can now close this window and return to CueCard.</p>
        <script>setTimeout(() => window.close(), 2000);</script>
        </body></html>"#
            .to_string(),
    )
}

fn oauth_error_page(message: &str) -> Html<String> {
    Html(format!(
        r#"<!DOCTYPE html>
        <html><head><title>Authentication Failed</title>
        <style>body {{ font-family: system-ui; padding: 40px; text-align: center; }}</style>
        </head><body>
        <h1>Authentication Failed</h1>
        <p>Error: {}</p>
        <p>You can close this window.</p>
        </body></html>"#,
        message
    ))
}

#[derive(Debug, Deserialize)]
struct GoogleTokenResponse {
    access_token: String,
    refresh_token: Option<String>,
    expires_in: Option<i64>,
    scope: Option<String>,
    id_token: Option<String>,
}

#[derive(Debug, Deserialize)]
struct FirebaseSignInResponse {
    #[serde(rename = "idToken")]
    id_token: String,
    #[serde(rename = "refreshToken")]
    refresh_token: Option<String>,
    #[serde(rename = "expiresIn")]
    expires_in: Option<String>,
    #[serde(rename = "email")]
    email: Option<String>,
    #[serde(rename = "displayName")]
    display_name: Option<String>,
    #[serde(rename = "photoUrl")]
    photo_url: Option<String>,
    #[serde(rename = "localId")]
    local_id: Option<String>,
}

#[derive(Debug, Deserialize)]
struct FirebaseAnonymousResponse {
    #[serde(rename = "idToken")]
    id_token: String,
}

#[derive(Debug, Clone, Deserialize)]
struct FirebaseSection {
    #[serde(rename = "apiKey")]
    api_key: String,
    #[serde(rename = "authDomain")]
    auth_domain: String,
    #[serde(rename = "projectId")]
    project_id: String,
    #[serde(rename = "storageBucket")]
    storage_bucket: Option<String>,
    #[serde(rename = "messagingSenderId")]
    messaging_sender_id: Option<String>,
    #[serde(rename = "appId")]
    app_id: String,
}

#[derive(Debug, Clone, Deserialize)]
struct RemoteConfigDocument {
    collection: String,
    document: String,
}

#[derive(Debug, Clone, Deserialize)]
struct FirebaseConfig {
    firebase: FirebaseSection,
    #[serde(rename = "configDocument")]
    config_document: RemoteConfigDocument,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct FirebaseClientConfigResponse {
    api_key: String,
    auth_domain: String,
    project_id: String,
    storage_bucket: Option<String>,
    messaging_sender_id: Option<String>,
    app_id: String,
    config_collection: String,
    config_document: String,
}

#[derive(Debug, Clone)]
struct GoogleOAuthConfig {
    client_id: String,
    client_secret: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct FirebaseUserInfo {
    email: String,
    #[serde(default)]
    display_name: Option<String>,
    #[serde(default)]
    photo_url: Option<String>,
    #[serde(default)]
    user_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct FirebaseSession {
    user: FirebaseUserInfo,
    id_token: String,
    #[serde(default)]
    refresh_token: Option<String>,
    #[serde(default)]
    expires_at: Option<i64>,
}

#[derive(Default)]
struct UsageCounts {
    paste: i64,
    slide: i64,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct FirebaseUserSessionResponse {
    authenticated: bool,
    email: Option<String>,
    display_name: Option<String>,
    photo_url: Option<String>,
}

fn app_handle() -> Option<AppHandle> {
    APP_HANDLE.read().as_ref().cloned()
}

fn encode_firestore_segment(segment: &str) -> String {
    urlencoding::encode(segment).into_owned()
}

fn expires_at_from_seconds(seconds: Option<i64>) -> Option<i64> {
    seconds.map(|secs| chrono::Utc::now().timestamp() + secs)
}

fn expires_at_from_str(seconds: Option<&str>) -> Option<i64> {
    seconds
        .and_then(|s| s.parse::<i64>().ok())
        .map(|secs| chrono::Utc::now().timestamp() + secs)
}

fn load_firebase_config() -> FirebaseConfig {
    let encoded = env!("FIREBASE_CONFIG_B64");
    let decoded = STANDARD
        .decode(encoded)
        .expect("Failed to decode FIREBASE_CONFIG_B64");
    serde_json::from_slice(&decoded).expect("Invalid firebase.config content")
}

fn firebase_client_config_response() -> FirebaseClientConfigResponse {
    let cfg = FIREBASE_CONFIG.clone();
    FirebaseClientConfigResponse {
        api_key: cfg.firebase.api_key,
        auth_domain: cfg.firebase.auth_domain,
        project_id: cfg.firebase.project_id,
        storage_bucket: cfg.firebase.storage_bucket,
        messaging_sender_id: cfg.firebase.messaging_sender_id,
        app_id: cfg.firebase.app_id,
        config_collection: cfg.config_document.collection,
        config_document: cfg.config_document.document,
    }
}

fn resolve_frontend_dir(app: &tauri::App) -> PathBuf {
    let dev_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .join("src");
    if dev_dir.exists() {
        println!("Serving frontend from {}", dev_dir.display());
        return dev_dir;
    }

    if let Ok(resource_dir) = app.path().resource_dir() {
        for candidate in ["src", "dist", "public"] {
            let candidate_path = resource_dir.join(candidate);
            if candidate_path.exists() {
                println!("Serving frontend from resources {}", candidate_path.display());
                return candidate_path;
            }
        }
    }

    panic!(
        "Unable to locate frontend assets. Checked {} and packaged resources.",
        dev_dir.display()
    );
}

fn get_google_oauth_config() -> Result<GoogleOAuthConfig, String> {
    GOOGLE_OAUTH_CONFIG
        .read()
        .as_ref()
        .cloned()
        .ok_or_else(|| "Google OAuth config not loaded yet".to_string())
}

fn generate_code_verifier() -> String {
    rand::thread_rng()
        .sample_iter(&Alphanumeric)
        .take(64)
        .map(char::from)
        .collect()
}

fn pkce_code_challenge(verifier: &str) -> String {
    let digest = Sha256::digest(verifier.as_bytes());
    URL_SAFE_NO_PAD.encode(digest)
}

fn take_pkce_code_verifier() -> Result<String, String> {
    let mut verifier = PKCE_CODE_VERIFIER.write();
    verifier
        .take()
        .ok_or_else(|| "Missing PKCE code verifier".to_string())
}

fn build_oauth_authorization_url(scope_url: &str) -> Result<String, String> {
    let oauth = get_google_oauth_config()?;
    let client_id = oauth.client_id;
    println!("Client ID: {}", client_id);
    
    let code_verifier = generate_code_verifier();
    let code_challenge = pkce_code_challenge(&code_verifier);

    println!("Code verifier: {}", code_verifier);
    println!("Code challenge: {}", code_challenge);

    {
        let mut verifier = PKCE_CODE_VERIFIER.write();
        *verifier = Some(code_verifier);
    }

    Ok(format!(
        "{}?client_id={}&redirect_uri={}&response_type=code&scope={}&access_type=offline&prompt=consent&include_granted_scopes=true&code_challenge={}&code_challenge_method=S256",
        GOOGLE_AUTH_URL,
        urlencoding::encode(&client_id),
        urlencoding::encode(REDIRECT_URI),
        urlencoding::encode(scope_url),
        code_challenge
    ))
}

// Health check endpoint
async fn health_handler() -> Json<serde_json::Value> {
    let is_authenticated = OAUTH_TOKENS.read().is_some();
    Json(serde_json::json!({
        "status": "ok",
        "server": "cuecard-app",
        "authenticated": is_authenticated
    }))
}

// Slides endpoint (POST) - receives slide data from extension
async fn slides_handler(Json(slide_data): Json<SlideData>) -> Result<Json<ApiResponse>, StatusCode> {
    println!("Received slide change: {:?}", slide_data);

    // Check if presentation changed - if so, prefetch all notes
    let presentation_changed = {
        let current_pres = CURRENT_PRESENTATION_ID.read();
        current_pres.as_ref() != Some(&slide_data.presentation_id)
    };

    if presentation_changed {
        println!("New presentation detected: {}", slide_data.presentation_id);
        // Update current presentation ID
        {
            let mut current_pres = CURRENT_PRESENTATION_ID.write();
            *current_pres = Some(slide_data.presentation_id.clone());
        }
        // Clear old notes cache and prefetch all notes for new presentation
        {
            let mut notes_cache = SLIDE_NOTES.write();
            notes_cache.clear();
        }
        // Prefetch all notes in the background
        let presentation_id = slide_data.presentation_id.clone();
        tokio::spawn(async move {
            let _ = prefetch_all_notes(&presentation_id).await;
        });
    }

    // Store the current slide
    {
        let mut current = CURRENT_SLIDE.write();
        *current = Some(slide_data.clone());
    }

    // Try to get notes from cache first, otherwise fetch
    let notes = {
        let notes_cache = SLIDE_NOTES.read();
        let key = format!("{}:{}", slide_data.presentation_id, slide_data.slide_id);
        notes_cache.get(&key).cloned()
    };

    let notes = match notes {
        Some(n) => Some(n),
        None => {
            // Not in cache, fetch and cache it
            let fetched = fetch_slide_notes(&slide_data.presentation_id, &slide_data.slide_id).await;
            if let Some(ref note_text) = fetched {
                let mut notes_cache = SLIDE_NOTES.write();
                let key = format!("{}:{}", slide_data.presentation_id, slide_data.slide_id);
                notes_cache.insert(key, note_text.clone());
            }
            fetched
        }
    };

    // Emit event to frontend
    if let Some(app) = APP_HANDLE.read().as_ref() {
        let event = SlideUpdateEvent {
            slide_data: slide_data.clone(),
            notes: notes.clone(),
        };
        let _ = app.emit("slide-update", event);
    }

    Ok(Json(ApiResponse {
        received: true,
        notes,
    }))
}

// OAuth2 login - redirects to Google
async fn oauth_login_handler() -> Result<Redirect, StatusCode> {
    let scope_url = {
        let pending = PENDING_OAUTH_SCOPE.read();
        match pending.as_deref() {
            Some("slides") => SCOPE_SLIDES.to_string(),
            _ => SCOPE_SLIDES.to_string(),
        }
    };

    match build_oauth_authorization_url(&scope_url) {
        Ok(url) => Ok(Redirect::temporary(&url)),
        Err(err) => {
            eprintln!("Failed to build OAuth URL: {}", err);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// OAuth2 callback - exchanges code for tokens
async fn oauth_callback_handler(Query(params): Query<OAuthCallback>) -> Html<String> {
    if let Some(error) = params.error {
        return oauth_error_page(&error);
    }

    let code = match params.code {
        Some(c) => c,
        None => {
            return oauth_error_page("No authorization code received.");
        }
    };

    let pending_scope = {
        let mut pending = PENDING_OAUTH_SCOPE.write();
        pending.take()
    };

    let token_response = match request_google_tokens(&code).await {
        Ok(tokens) => tokens,
        Err(err) => return oauth_error_page(&err),
    };

    let result = match pending_scope.as_deref() {
        Some("firebase") => handle_firebase_oauth_flow(token_response).await,
        _ => handle_slides_oauth_flow(token_response, pending_scope).await,
    };

    match result {
        Ok(_) => oauth_success_page(),
        Err(err) => oauth_error_page(&err),
    }
}

// Exchange authorization code for tokens
async fn request_google_tokens(code: &str) -> Result<GoogleTokenResponse, String> {
    let oauth = get_google_oauth_config()?;
    let client_id = oauth.client_id;
    let client_secret = oauth.client_secret;
    let code_verifier = take_pkce_code_verifier()?;

    let client = reqwest::Client::new();
    let response = client
        .post(GOOGLE_TOKEN_URL)
        .form(&[
            ("code", code),
            ("client_id", client_id.as_str()),
            ("client_secret", client_secret.as_str()),
            ("redirect_uri", REDIRECT_URI),
            ("grant_type", "authorization_code"),
            ("code_verifier", code_verifier.as_str()),
        ])
        .send()
        .await
        .map_err(|e| format!("Token request failed: {}", e))?;

    if !response.status().is_success() {
        let error_text = response.text().await.unwrap_or_default();
        return Err(format!("Token exchange failed: {}", error_text));
    }

    let token_response: GoogleTokenResponse = response
        .json()
        .await
        .map_err(|e| format!("Failed to parse token response: {}", e))?;

    Ok(token_response)
}

fn oauth_tokens_from_response(token_response: GoogleTokenResponse) -> OAuthTokens {
    let expires_at = expires_at_from_seconds(token_response.expires_in);

    let granted_scopes: Vec<String> = token_response
        .scope
        .as_deref()
        .unwrap_or("")
        .split_whitespace()
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
        .collect();

    OAuthTokens {
        access_token: token_response.access_token,
        refresh_token: token_response.refresh_token,
        expires_at,
        granted_scopes,
    }
}

async fn handle_slides_oauth_flow(
    token_response: GoogleTokenResponse,
    pending_scope: Option<String>,
) -> Result<(), String> {
    let mut new_tokens = oauth_tokens_from_response(token_response);

    {
        let mut oauth = OAUTH_TOKENS.write();
        if let Some(ref existing) = *oauth {
            if new_tokens.refresh_token.is_none() {
                new_tokens.refresh_token = existing.refresh_token.clone();
            }
            for scope in &existing.granted_scopes {
                if !new_tokens.granted_scopes.contains(scope) {
                    new_tokens.granted_scopes.push(scope.clone());
                }
            }
        }
        *oauth = Some(new_tokens);
    }

    let granted_scopes: Vec<String> = {
        let oauth = OAUTH_TOKENS.read();
        oauth
            .as_ref()
            .map(|t| t.granted_scopes.clone())
            .unwrap_or_default()
    };

    if let Some(app) = app_handle() {
        save_tokens_to_store(&app);
        let _ = app.emit("auth-status", serde_json::json!({
            "authenticated": true,
            "granted_scopes": granted_scopes,
            "requested_scope": pending_scope
        }));
    }

    Ok(())
}

async fn handle_firebase_oauth_flow(token_response: GoogleTokenResponse) -> Result<(), String> {
    let google_id_token = token_response
        .id_token
        .ok_or_else(|| "Missing ID token in Google response".to_string())?;

    let session = sign_in_with_firebase_using_google(&google_id_token).await?;
    persist_firebase_session(session.clone());

    fetch_google_oauth_config_with_token(&session.id_token).await?;
    sync_user_profile().await?;

    Ok(())
}

// Refresh access token
async fn refresh_access_token() -> Result<(), String> {
    let refresh_token = {
        let tokens = OAUTH_TOKENS.read();
        tokens
            .as_ref()
            .and_then(|t| t.refresh_token.clone())
            .ok_or("No refresh token available")?
    };

    let oauth = get_google_oauth_config()?;
    let client_id = oauth.client_id;
    let client_secret = oauth.client_secret;

    let client = reqwest::Client::new();
    let response = client
        .post(GOOGLE_TOKEN_URL)
        .form(&[
            ("refresh_token", refresh_token.as_str()),
            ("client_id", client_id.as_str()),
            ("client_secret", client_secret.as_str()),
            ("grant_type", "refresh_token"),
        ])
        .send()
        .await
        .map_err(|e| format!("Token refresh failed: {}", e))?;

    if !response.status().is_success() {
        let error_text = response.text().await.unwrap_or_default();
        return Err(format!("Token refresh failed: {}", error_text));
    }

    let token_response: GoogleTokenResponse = response
        .json()
        .await
        .map_err(|e| format!("Failed to parse token response: {}", e))?;

    let expires_at = token_response
        .expires_in
        .map(|secs| chrono::Utc::now().timestamp() + secs);

    // Parse any new scopes from the response
    let new_scopes: Vec<String> = token_response
        .scope
        .map(|s| s.split_whitespace().map(|s| s.to_string()).collect())
        .unwrap_or_default();

    // Update tokens (keep existing refresh token and merge scopes if new one not provided)
    {
        let mut tokens = OAUTH_TOKENS.write();
        if let Some(ref mut t) = *tokens {
            t.access_token = token_response.access_token;
            if token_response.refresh_token.is_some() {
                t.refresh_token = token_response.refresh_token;
            }
            t.expires_at = expires_at;
            // Merge new scopes with existing ones
            if !new_scopes.is_empty() {
                for scope in new_scopes {
                    if !t.granted_scopes.contains(&scope) {
                        t.granted_scopes.push(scope);
                    }
                }
            }
        }
    }

    // Save updated tokens to persistent storage
    if let Some(app) = APP_HANDLE.read().as_ref() {
        save_tokens_to_store(app);
    }

    Ok(())
}

// Save OAuth tokens to persistent storage
fn save_tokens_to_store(app: &AppHandle) {
    if let Ok(store) = app.store("cuecard-store.json") {
        let tokens = OAUTH_TOKENS.read();
        if let Some(ref t) = *tokens {
            if let Ok(json) = serde_json::to_value(t) {
                let _ = store.set("oauth_tokens", json);
                let _ = store.save();
                println!("Saved OAuth tokens to storage");
            }
        }
    }
}

// Clear OAuth tokens from persistent storage
fn clear_tokens_from_store(app: &AppHandle) {
    if let Ok(store) = app.store("cuecard-store.json") {
        let _ = store.delete("oauth_tokens");
        let _ = store.save();
        println!("Cleared OAuth tokens from storage");
    }
}

fn save_firebase_session_to_store(app: &AppHandle) {
    if let Ok(store) = app.store("cuecard-store.json") {
        let session = FIREBASE_SESSION.read();
        if let Some(ref s) = *session {
            if let Ok(json) = serde_json::to_value(s) {
                let _ = store.set("firebase_session", json);
                let _ = store.save();
                println!("Saved Firebase session to storage");
            }
        }
    }
}

fn clear_firebase_session_store(app: &AppHandle) {
    if let Ok(store) = app.store("cuecard-store.json") {
        let _ = store.delete("firebase_session");
        let _ = store.save();
        println!("Cleared Firebase session from storage");
    }
}

fn emit_user_session(session: Option<FirebaseUserInfo>) {
    if let Some(app) = app_handle() {
        let payload = serde_json::json!({
            "authenticated": session.is_some(),
            "email": session.as_ref().map(|s| s.email.clone()),
            "displayName": session.as_ref().and_then(|s| s.display_name.clone()),
            "photoUrl": session.as_ref().and_then(|s| s.photo_url.clone()),
        });
        let _ = app.emit("user-session", payload);
    }
}

fn persist_firebase_session(session: FirebaseSession) {
    {
        let mut guard = FIREBASE_SESSION.write();
        *guard = Some(session.clone());
    }

    if let Some(app) = app_handle() {
        save_firebase_session_to_store(&app);
    }

    emit_user_session(Some(session.user.clone()));
}

fn clear_firebase_session() {
    {
        let mut guard = FIREBASE_SESSION.write();
        *guard = None;
    }

    if let Some(app) = app_handle() {
        clear_firebase_session_store(&app);
    }

    emit_user_session(None);
}

// Get valid access token (refreshes if needed)
async fn get_valid_access_token() -> Option<String> {
    let (access_token, expires_at, has_refresh) = {
        let tokens = OAUTH_TOKENS.read();
        match tokens.as_ref() {
            Some(t) => (
                t.access_token.clone(),
                t.expires_at,
                t.refresh_token.is_some(),
            ),
            None => return None,
        }
    };

    // Check if token is expired or about to expire (within 5 minutes)
    let now = chrono::Utc::now().timestamp();
    let is_expired = expires_at.map(|exp| now >= exp - 300).unwrap_or(false);

    if is_expired && has_refresh {
        if let Err(e) = refresh_access_token().await {
            eprintln!("Failed to refresh token: {}", e);
            return None;
        }
        // Return the new token
        let tokens = OAUTH_TOKENS.read();
        return tokens.as_ref().map(|t| t.access_token.clone());
    }

    Some(access_token)
}

#[derive(Debug, Deserialize)]
struct FirebaseRefreshResponse {
    #[serde(rename = "id_token")]
    id_token: String,
    #[serde(rename = "refresh_token")]
    refresh_token: Option<String>,
    #[serde(rename = "expires_in")]
    expires_in: Option<String>,
}

async fn ensure_firebase_id_token() -> Result<String, String> {
    let (id_token, expires_at, refresh_token) = {
        let session = FIREBASE_SESSION.read();
        match session.as_ref() {
            Some(s) => (
                s.id_token.clone(),
                s.expires_at,
                s.refresh_token.clone(),
            ),
            None => return Err("Not authenticated with Firebase".to_string()),
        }
    };

    let now = chrono::Utc::now().timestamp();
    let needs_refresh = expires_at.map(|exp| now >= exp - 300).unwrap_or(false);

    if needs_refresh {
        let refresh_token = refresh_token.ok_or_else(|| "Missing refresh token".to_string())?;
        let (new_token, new_refresh, new_expires) =
            refresh_firebase_token(&refresh_token).await?;

        {
            let mut session = FIREBASE_SESSION.write();
            if let Some(ref mut existing) = *session {
                existing.id_token = new_token.clone();
                if let Some(refresh) = new_refresh.clone() {
                    existing.refresh_token = Some(refresh);
                }
                existing.expires_at = new_expires;
            }
        }

        if let Some(app) = app_handle() {
            save_firebase_session_to_store(&app);
        }

        return Ok(new_token);
    }

    Ok(id_token)
}

async fn refresh_firebase_token(
    refresh_token: &str,
) -> Result<(String, Option<String>, Option<i64>), String> {
    let api_key = &FIREBASE_CONFIG.firebase.api_key;
    let url = format!("{}?key={}", FIREBASE_TOKEN_REFRESH_URL, api_key);
    let client = reqwest::Client::new();
    let response = client
        .post(&url)
        .form(&[
            ("grant_type", "refresh_token"),
            ("refresh_token", refresh_token),
        ])
        .send()
        .await
        .map_err(|e| format!("Failed to refresh Firebase token: {}", e))?;

    if !response.status().is_success() {
        let text = response.text().await.unwrap_or_default();
        return Err(format!("Firebase refresh failed: {}", text));
    }

    let body: FirebaseRefreshResponse = response
        .json()
        .await
        .map_err(|e| format!("Failed to parse Firebase refresh response: {}", e))?;

    let expires_at = expires_at_from_str(body.expires_in.as_deref());
    Ok((body.id_token, body.refresh_token, expires_at))
}

fn firestore_document_url(segments: &[String]) -> String {
    let project = &FIREBASE_CONFIG.firebase.project_id;
    let path = segments.join("/");
    format!(
        "{}/projects/{}/databases/(default)/documents/{}",
        FIRESTORE_BASE_URL, project, path
    )
}

async fn firestore_get_document(
    segments: &[String],
    id_token: &str,
) -> Result<Option<Value>, String> {
    let url = firestore_document_url(segments);
    let client = reqwest::Client::new();
    let response = client
        .get(&url)
        .query(&[("key", FIREBASE_CONFIG.firebase.api_key.as_str())])
        .bearer_auth(id_token)
        .send()
        .await
        .map_err(|e| format!("Failed to fetch Firestore document: {}", e))?;

    if response.status() == StatusCode::NOT_FOUND {
        return Ok(None);
    }

    if !response.status().is_success() {
        let text = response.text().await.unwrap_or_default();
        return Err(format!("Firestore request failed: {}", text));
    }

    let json: Value = response
        .json()
        .await
        .map_err(|e| format!("Failed to parse Firestore response: {}", e))?;
    Ok(Some(json))
}

async fn firestore_upsert_document(
    segments: &[String],
    id_token: &str,
    body: Value,
) -> Result<(), String> {
    let url = firestore_document_url(segments);
    let client = reqwest::Client::new();
    let response = client
        .patch(&url)
        .query(&[("key", FIREBASE_CONFIG.firebase.api_key.as_str())])
        .bearer_auth(id_token)
        .json(&body)
        .send()
        .await
        .map_err(|e| format!("Failed to write Firestore document: {}", e))?;

    if !response.status().is_success() {
        let text = response.text().await.unwrap_or_default();
        return Err(format!("Firestore update failed: {}", text));
    }

    Ok(())
}

fn firestore_string_field(doc: &Value, field: &str) -> Option<String> {
    doc.get("fields")?
        .get(field)?
        .get("stringValue")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
}

fn config_document_segments() -> Vec<String> {
    vec![
        encode_firestore_segment(&FIREBASE_CONFIG.config_document.collection),
        encode_firestore_segment(&FIREBASE_CONFIG.config_document.document),
    ]
}

fn profile_document_segments(email: &str) -> Vec<String> {
    vec![
        encode_firestore_segment("Profiles"),
        encode_firestore_segment(email),
    ]
}

fn parse_usage_counts(doc: &Value) -> UsageCounts {
    let usage_fields = doc
        .get("fields")
        .and_then(|f| f.get("usage"))
        .and_then(|u| u.get("mapValue"))
        .and_then(|mv| mv.get("fields"));

    let paste = usage_fields
        .and_then(|fields| fields.get("paste"))
        .and_then(|value| {
            if let Some(int_val) = value.get("integerValue").and_then(|v| v.as_str()) {
                return int_val.parse::<i64>().ok();
            }
            value.get("doubleValue").and_then(|v| v.as_f64()).map(|v| v as i64)
        })
        .unwrap_or(0);

    let slide = usage_fields
        .and_then(|fields| fields.get("slide"))
        .and_then(|value| {
            if let Some(int_val) = value.get("integerValue").and_then(|v| v.as_str()) {
                return int_val.parse::<i64>().ok();
            }
            value.get("doubleValue").and_then(|v| v.as_f64()).map(|v| v as i64)
        })
        .unwrap_or(0);

    UsageCounts { paste, slide }
}

fn usage_fields_json(counts: &UsageCounts) -> Value {
    serde_json::json!({
        "mapValue": {
            "fields": {
                "paste": { "integerValue": counts.paste.to_string() },
                "slide": { "integerValue": counts.slide.to_string() }
            }
        }
    })
}

async fn fetch_google_oauth_config_with_token(id_token: &str) -> Result<(), String> {
    let segments = config_document_segments();
    let doc = firestore_get_document(&segments, id_token).await?;
    let doc = doc.ok_or_else(|| "Config document not found in Firestore".to_string())?;

    let fields = doc
        .get("fields")
        .ok_or_else(|| "Config document missing fields".to_string())?;

    let client_id = fields
        .get("googleClientId")
        .and_then(|v| v.get("stringValue"))
        .and_then(|v| v.as_str())
        .ok_or_else(|| "googleClientId missing".to_string())?;

    let client_secret = fields
        .get("googleClientSecret")
        .and_then(|v| v.get("stringValue"))
        .and_then(|v| v.as_str())
        .ok_or_else(|| "googleClientSecret missing".to_string())?;

    apply_google_oauth_config(client_id, client_secret)
}

async fn firebase_anonymous_token() -> Result<String, String> {
    let api_key = &FIREBASE_CONFIG.firebase.api_key;
    let url = format!("{}?key={}", FIREBASE_SIGN_UP_URL, api_key);
    let client = reqwest::Client::new();
    let response = client
        .post(&url)
        .json(&serde_json::json!({
            "returnSecureToken": true
        }))
        .send()
        .await
        .map_err(|e| format!("Failed to sign in anonymously: {}", e))?;

    if !response.status().is_success() {
        let text = response.text().await.unwrap_or_default();
        return Err(format!("Anonymous sign-in failed: {}", text));
    }

    let body: FirebaseAnonymousResponse = response
        .json()
        .await
        .map_err(|e| format!("Failed to parse anonymous sign-in response: {}", e))?;

    Ok(body.id_token)
}

async fn ensure_google_oauth_config_loaded() -> Result<(), String> {
    {
        let config = GOOGLE_OAUTH_CONFIG.read();
        if config.is_some() {
            return Ok(());
        }
    }

    match firebase_anonymous_token().await {
        Ok(token) => fetch_google_oauth_config_with_token(&token).await,
        Err(err) => Err(err),
    }
}

async fn sign_in_with_firebase_using_google(id_token: &str) -> Result<FirebaseSession, String> {
    let api_key = &FIREBASE_CONFIG.firebase.api_key;
    let url = format!("{}?key={}", FIREBASE_SIGN_IN_URL, api_key);
    let post_body = format!(
        "id_token={}&providerId=google.com",
        urlencoding::encode(id_token)
    );

    let client = reqwest::Client::new();
    let response = client
        .post(&url)
        .json(&serde_json::json!({
            "postBody": post_body,
            "requestUri": REDIRECT_URI,
            "returnSecureToken": true,
            "returnIdpCredential": true
        }))
        .send()
        .await
        .map_err(|e| format!("Failed to sign in with Firebase: {}", e))?;

    if !response.status().is_success() {
        let text = response.text().await.unwrap_or_default();
        return Err(format!("Firebase sign-in failed: {}", text));
    }

    let body: FirebaseSignInResponse = response
        .json()
        .await
        .map_err(|e| format!("Failed to parse Firebase sign-in response: {}", e))?;

    let expires_at = expires_at_from_str(body.expires_in.as_deref());

    let user = FirebaseUserInfo {
        email: body
            .email
            .clone()
            .ok_or_else(|| "Firebase response missing email".to_string())?,
        display_name: body.display_name.clone(),
        photo_url: body.photo_url.clone(),
        user_id: body.local_id.clone(),
    };

    Ok(FirebaseSession {
        user,
        id_token: body.id_token,
        refresh_token: body.refresh_token,
        expires_at,
    })
}

async fn sync_user_profile() -> Result<(), String> {
    let session = {
        let guard = FIREBASE_SESSION.read();
        guard.clone().ok_or_else(|| "Not authenticated".to_string())?
    };

    let id_token = ensure_firebase_id_token().await?;
    let email = &session.user.email;
    let doc_segments = profile_document_segments(email);
    let existing = firestore_get_document(&doc_segments, &id_token).await?;

    let creation_date = existing
        .as_ref()
        .and_then(|doc| firestore_string_field(doc, "creationDate"))
        .unwrap_or_else(|| chrono::Utc::now().to_rfc3339());

    let usage = existing
        .as_ref()
        .map(|doc| parse_usage_counts(doc))
        .unwrap_or_default();

    let display_name = session
        .user
        .display_name
        .clone()
        .unwrap_or_else(|| session.user.email.clone());

    let body = serde_json::json!({
        "fields": {
            "name": { "stringValue": display_name },
            "email": { "stringValue": email },
            "creationDate": { "stringValue": creation_date },
            "usage": usage_fields_json(&usage)
        }
    });

    firestore_upsert_document(&doc_segments, &id_token, body).await
}

async fn increment_usage_counter(usage_type: &str) -> Result<(), String> {
    let session = {
        let guard = FIREBASE_SESSION.read();
        guard.clone().ok_or_else(|| "Not authenticated".to_string())?
    };

    let id_token = ensure_firebase_id_token().await?;
    let email = &session.user.email;
    let doc_segments = profile_document_segments(email);
    let existing = firestore_get_document(&doc_segments, &id_token).await?;

    let mut usage = existing
        .as_ref()
        .map(|doc| parse_usage_counts(doc))
        .unwrap_or_default();

    match usage_type {
        "paste" => usage.paste += 1,
        "slide" => usage.slide += 1,
        _ => return Err("Invalid usage type".to_string()),
    }

    let creation_date = existing
        .as_ref()
        .and_then(|doc| firestore_string_field(doc, "creationDate"))
        .unwrap_or_else(|| chrono::Utc::now().to_rfc3339());

    let display_name = session
        .user
        .display_name
        .clone()
        .unwrap_or_else(|| session.user.email.clone());

    let body = serde_json::json!({
        "fields": {
            "name": { "stringValue": display_name },
            "email": { "stringValue": email },
            "creationDate": { "stringValue": creation_date },
            "usage": usage_fields_json(&usage)
        }
    });

    firestore_upsert_document(&doc_segments, &id_token, body).await
}

// Prefetch all notes for a presentation
async fn prefetch_all_notes(presentation_id: &str) -> Result<(), String> {
    let access_token = match get_valid_access_token().await {
        Some(token) => token,
        None => {
            println!("Not authenticated. Cannot prefetch notes.");
            return Err("Not authenticated".to_string());
        }
    };

    let url = format!(
        "https://slides.googleapis.com/v1/presentations/{}",
        presentation_id
    );

    let client = reqwest::Client::new();
    let response = match client
        .get(&url)
        .header("Authorization", format!("Bearer {}", access_token))
        .send()
        .await
    {
        Ok(r) => r,
        Err(e) => {
            eprintln!("Error fetching slides API for prefetch: {}", e);
            return Err(e.to_string());
        }
    };

    if !response.status().is_success() {
        let status = response.status();
        let error_body = response.text().await.unwrap_or_default();
        eprintln!("Slides API error during prefetch: {} - {}", status, error_body);
        return Err(format!("API error: {}", status));
    }

    let json: serde_json::Value = match response.json().await {
        Ok(j) => j,
        Err(e) => {
            eprintln!("Failed to parse slides response during prefetch: {}", e);
            return Err(e.to_string());
        }
    };

    // Extract notes for all slides
    let slides = match json.get("slides").and_then(|s| s.as_array()) {
        Some(s) => s,
        None => return Ok(()),
    };

    let mut notes_cache = SLIDE_NOTES.write();
    let mut count = 0;

    for slide in slides {
        if let Some(obj_id) = slide.get("objectId").and_then(|o| o.as_str()) {
            if let Some(notes_text) = extract_notes_from_slide(slide) {
                let key = format!("{}:{}", presentation_id, obj_id);
                notes_cache.insert(key, notes_text);
                count += 1;
            }
        }
    }

    println!("Prefetched {} slide notes for presentation {}", count, presentation_id);
    Ok(())
}

// Extract notes from a single slide JSON object
fn extract_notes_from_slide(slide: &serde_json::Value) -> Option<String> {
    let notes = slide
        .get("slideProperties")?
        .get("notesPage")?
        .get("pageElements")?
        .as_array()?;

    for element in notes {
        if let Some(shape) = element.get("shape") {
            if let Some(placeholder) = shape.get("placeholder") {
                if placeholder.get("type")?.as_str()? == "BODY" {
                    if let Some(text) = shape.get("text") {
                        return extract_text_from_text_elements(text);
                    }
                }
            }
        }
    }

    None
}

// Fetch notes from Google Slides API using OAuth2
async fn fetch_slide_notes(presentation_id: &str, slide_id: &str) -> Option<String> {
    let access_token = match get_valid_access_token().await {
        Some(token) => token,
        None => {
            println!("Not authenticated. Please sign in with Google.");
            return None;
        }
    };

    let url = format!(
        "https://slides.googleapis.com/v1/presentations/{}",
        presentation_id
    );

    let client = reqwest::Client::new();
    let response = match client
        .get(&url)
        .header("Authorization", format!("Bearer {}", access_token))
        .send()
        .await
    {
        Ok(r) => r,
        Err(e) => {
            eprintln!("Error fetching slides API: {}", e);
            return None;
        }
    };

    if !response.status().is_success() {
        let status = response.status();
        let error_body = response.text().await.unwrap_or_default();
        eprintln!("Slides API error: {} - Response body: {}", status, error_body);
        eprintln!("Presentation ID: {}, Slide ID: {}", presentation_id, slide_id);
        return None;
    }

    let json: serde_json::Value = match response.json().await {
        Ok(j) => j,
        Err(e) => {
            eprintln!("Failed to parse slides response: {}", e);
            return None;
        }
    };

    // Find the slide and extract speaker notes
    let slides = json.get("slides")?.as_array()?;
    for slide in slides {
        let obj_id = slide.get("objectId")?.as_str()?;
        if obj_id == slide_id {
            let notes = slide
                .get("slideProperties")?
                .get("notesPage")?
                .get("pageElements")?
                .as_array()?;

            for element in notes {
                if let Some(shape) = element.get("shape") {
                    if let Some(placeholder) = shape.get("placeholder") {
                        if placeholder.get("type")?.as_str()? == "BODY" {
                            if let Some(text) = shape.get("text") {
                                return extract_text_from_text_elements(text);
                            }
                        }
                    }
                }
            }
        }
    }

    None
}

// Extract text content from Google Slides text elements
fn extract_text_from_text_elements(text: &serde_json::Value) -> Option<String> {
    let elements = text.get("textElements")?.as_array()?;
    let mut result = String::new();

    for element in elements {
        if let Some(text_run) = element.get("textRun") {
            if let Some(content) = text_run.get("content").and_then(|c| c.as_str()) {
                result.push_str(content);
            }
        }
    }

    if result.is_empty() {
        None
    } else {
        Some(result.trim().to_string())
    }
}

// Auth status endpoint
async fn auth_status_handler() -> Json<serde_json::Value> {
    let is_authenticated = OAUTH_TOKENS.read().is_some();
    Json(serde_json::json!({
        "authenticated": is_authenticated
    }))
}

// Logout endpoint
async fn logout_handler() -> Json<serde_json::Value> {
    {
        let mut tokens = OAUTH_TOKENS.write();
        *tokens = None;
    }

    if let Some(app) = APP_HANDLE.read().as_ref() {
        // Clear tokens from persistent storage
        clear_tokens_from_store(app);

        let _ = app.emit("auth-status", serde_json::json!({
            "authenticated": false,
            "granted_scopes": [],
            "requested_scope": null
        }));
    }

    Json(serde_json::json!({
        "success": true
    }))
}

// Start the web server
async fn start_server(static_dir: PathBuf) {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let index_file = static_dir.join("index.html");
    let static_service =
        ServeDir::new(static_dir.clone()).not_found_service(ServeFile::new(index_file));

    let app = Router::new()
        .route("/health", get(health_handler))
        .route("/slides", post(slides_handler))
        .route("/oauth/login", get(oauth_login_handler))
        .route("/oauth/callback", get(oauth_callback_handler))
        .route("/oauth/status", get(auth_status_handler))
        .route("/oauth/logout", post(logout_handler))
        .layer(cors)
        .fallback_service(static_service);

    let listener = tokio::net::TcpListener::bind("127.0.0.1:3642")
        .await
        .expect("Failed to bind to port 3642");

    println!("Server running on http://127.0.0.1:3642");

    axum::serve(listener, app).await.expect("Server error");
}

// Tauri command to get current slide data
#[tauri::command]
fn get_current_slide() -> Option<SlideData> {
    CURRENT_SLIDE.read().clone()
}

// Tauri command to get notes for current slide
#[tauri::command]
fn get_current_notes() -> Option<String> {
    let current = CURRENT_SLIDE.read();
    if let Some(ref slide) = *current {
        let notes = SLIDE_NOTES.read();
        let key = format!("{}:{}", slide.presentation_id, slide.slide_id);
        notes.get(&key).cloned()
    } else {
        None
    }
}

// Tauri command to check auth status
#[tauri::command]
fn get_auth_status() -> bool {
    OAUTH_TOKENS.read().is_some()
}

// Tauri command to get granted scopes
#[tauri::command]
fn get_granted_scopes() -> Vec<String> {
    OAUTH_TOKENS
        .read()
        .as_ref()
        .map(|t| t.granted_scopes.clone())
        .unwrap_or_default()
}

// Tauri command to check if a specific scope is granted
#[tauri::command]
fn has_scope(scope: String) -> bool {
    let scope_url = match scope.as_str() {
        "slides" => SCOPE_SLIDES,
        _ => return false,
    };
    OAUTH_TOKENS
        .read()
        .as_ref()
        .map(|t| t.granted_scopes.iter().any(|s| s == scope_url))
        .unwrap_or(false)
}

// Tauri command to initiate login - opens browser directly
// scope parameter can be "profile" or "slides"
#[tauri::command]
async fn start_login(app: AppHandle, scope: String) -> Result<(), String> {
    println!("Starting OAuth2 login flow for scope: {}", scope);

    ensure_google_oauth_config_loaded().await?;

    println!("Google OAuth config loaded");
    // Determine which scope(s) to request
    let scope_url = match scope.as_str() {
        "firebase" => SCOPE_PROFILE.to_string(),
        "slides" | _ => SCOPE_SLIDES.to_string(),
    };

    // Store the pending scope for the callback
    {
        let mut pending = PENDING_OAUTH_SCOPE.write();
        *pending = Some(scope.clone());
    }

    let auth_url = build_oauth_authorization_url(&scope_url)?;
    println!("Opening browser to URL: {}", auth_url);

    app.opener()
        .open_url(&auth_url, None::<&str>)
        .map_err(|e| format!("Failed to open browser: {}", e))?;

    Ok(())
}

// Tauri command to logout
#[tauri::command]
fn logout(app: AppHandle) {
    let mut tokens = OAUTH_TOKENS.write();
    *tokens = None;
    drop(tokens); // Release lock before calling clear_tokens_from_store

    // Clear tokens from persistent storage
    clear_tokens_from_store(&app);
}

// Tauri command to refresh notes for current slide/presentation
#[tauri::command]
async fn refresh_notes(app: AppHandle) -> Result<Option<String>, String> {
    let current_slide = {
        CURRENT_SLIDE.read().clone()
    };

    let slide_data = match current_slide {
        Some(s) => s,
        None => return Err("No current slide".to_string()),
    };

    // Clear cache for this presentation and refetch all notes
    {
        let mut notes_cache = SLIDE_NOTES.write();
        // Remove all notes for this presentation
        notes_cache.retain(|k, _| !k.starts_with(&format!("{}:", slide_data.presentation_id)));
    }

    // Refetch all notes
    let _ = prefetch_all_notes(&slide_data.presentation_id).await;

    // Get notes for current slide
    let notes = {
        let notes_cache = SLIDE_NOTES.read();
        let key = format!("{}:{}", slide_data.presentation_id, slide_data.slide_id);
        notes_cache.get(&key).cloned()
    };

    // Emit event to frontend with refreshed notes
    let event = SlideUpdateEvent {
        slide_data: slide_data.clone(),
        notes: notes.clone(),
    };
    let _ = app.emit("slide-update", event);

    Ok(notes)
}

// Tauri command to set window opacity/transparency
#[tauri::command]
fn set_window_opacity(app: AppHandle, opacity: f64) -> Result<(), String> {
    let window = app.get_webview_window("main").ok_or("Failed to get main window")?;

    // Clamp opacity between 0.1 and 1.0
    let clamped_opacity = opacity.max(0.1).min(1.0);

    #[cfg(target_os = "macos")]
    {
        use cocoa::appkit::NSWindow;
        use cocoa::base::id;

        let ns_window = window.ns_window().map_err(|e| format!("Failed to get NSWindow: {}", e))? as id;
        unsafe {
            ns_window.setAlphaValue_(clamped_opacity);
        }
    }

    #[cfg(target_os = "windows")]
    {
        use windows::Win32::Foundation::HWND;
        use windows::Win32::Graphics::Gdi::UpdateWindow;
        use windows::Win32::UI::WindowsAndMessaging::{
            GetWindowLongW, SetLayeredWindowAttributes, SetWindowLongW, GWL_EXSTYLE, LWA_ALPHA,
            WS_EX_LAYERED,
        };

        let hwnd = HWND(window.hwnd().map_err(|e| format!("Failed to get HWND: {}", e))?.0 as _);

        unsafe {
            // Get current extended style
            let ex_style = GetWindowLongW(hwnd, GWL_EXSTYLE);

            // Add WS_EX_LAYERED style if not present
            SetWindowLongW(hwnd, GWL_EXSTYLE, ex_style | WS_EX_LAYERED.0 as i32);

            // Set the opacity (0-255)
            let alpha = (clamped_opacity * 255.0) as u8;
            SetLayeredWindowAttributes(hwnd, None, alpha, LWA_ALPHA)
                .map_err(|e| format!("Failed to set window opacity: {}", e))?;

            let _ = UpdateWindow(hwnd);
        }
    }

    #[cfg(target_os = "linux")]
    {
        // On Linux, transparency is handled by the compositor
        // We can try to set the opacity hint, but it depends on the window manager
        // For now, we'll just acknowledge the request
        let _ = clamped_opacity;
        println!("Note: Dynamic opacity control on Linux depends on your window manager/compositor");
    }

    Ok(())
}

// Tauri command to get current window opacity
#[tauri::command]
fn get_window_opacity(app: AppHandle) -> Result<f64, String> {
    let window = app.get_webview_window("main").ok_or("Failed to get main window")?;

    #[cfg(target_os = "macos")]
    {
        use cocoa::appkit::NSWindow;
        use cocoa::base::id;

        let ns_window = window.ns_window().map_err(|e| format!("Failed to get NSWindow: {}", e))? as id;
        let opacity = unsafe { ns_window.alphaValue() };
        Ok(opacity)
    }

    #[cfg(target_os = "windows")]
    {
        use windows::Win32::Foundation::HWND;
        use windows::Win32::UI::WindowsAndMessaging::{GetLayeredWindowAttributes, GWL_EXSTYLE, GetWindowLongW, WS_EX_LAYERED};

        let hwnd = HWND(window.hwnd().map_err(|e| format!("Failed to get HWND: {}", e))?.0 as _);

        unsafe {
            let ex_style = GetWindowLongW(hwnd, GWL_EXSTYLE);
            if (ex_style & WS_EX_LAYERED.0 as i32) != 0 {
                let mut alpha: u8 = 255;
                let _ = GetLayeredWindowAttributes(hwnd, None, Some(&mut alpha), None);
                Ok(alpha as f64 / 255.0)
            } else {
                Ok(1.0)
            }
        }
    }

    #[cfg(target_os = "linux")]
    {
        let _ = window;
        Ok(1.0) // Default to fully opaque on Linux
    }
}

// Tauri command to enable/disable screenshot protection
#[tauri::command]
fn set_screenshot_protection(app: AppHandle, enabled: bool) -> Result<(), String> {
    let window = app.get_webview_window("main").ok_or("Failed to get main window")?;

    #[cfg(target_os = "macos")]
    {
        use cocoa::base::id;

        let ns_window = window.ns_window().map_err(|e| format!("Failed to get NSWindow: {}", e))? as id;
        unsafe {
            if enabled {
                // NSWindowSharingNone = 0 prevents the window from being captured
                let _: () = msg_send![ns_window, setSharingType: 0u64];
            } else {
                // NSWindowSharingReadOnly = 1 allows capturing
                let _: () = msg_send![ns_window, setSharingType: 1u64];
            }
        }
    }

    #[cfg(target_os = "windows")]
    {
        use windows::Win32::Foundation::HWND;
        use windows::Win32::UI::WindowsAndMessaging::{SetWindowDisplayAffinity, WDA_EXCLUDEFROMCAPTURE, WDA_NONE};

        let hwnd = HWND(window.hwnd().map_err(|e| format!("Failed to get HWND: {}", e))?.0 as _);

        unsafe {
            let affinity = if enabled {
                WDA_EXCLUDEFROMCAPTURE // Exclude from screen capture
            } else {
                WDA_NONE // Allow screen capture
            };

            SetWindowDisplayAffinity(hwnd, affinity)
                .map_err(|e| format!("Failed to set display affinity: {}", e))?;
        }
    }

    #[cfg(target_os = "linux")]
    {
        let _ = (window, enabled);
        println!("Warning: Screenshot protection is not reliably supported on Linux");
        println!("Linux screenshot protection depends on compositor support and may not work");
        // On Linux, there's no standard way to prevent screenshots across all desktop environments
        // Some compositors might support _NET_WM_STATE_HIDDEN or similar, but it's not universal
    }

    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_store::Builder::default().build())
        .setup(|app| {
            // Store app handle for emitting events
            {
                let mut handle = APP_HANDLE.write();
                *handle = Some(app.handle().clone());
            }

            // Load stored OAuth tokens from persistent storage
            if let Ok(store) = app.store("cuecard-store.json") {
                if let Some(tokens_json) = store.get("oauth_tokens") {
                    if let Ok(tokens) = serde_json::from_value::<OAuthTokens>(tokens_json.clone()) {
                        println!("Loaded OAuth tokens from storage");
                        let mut oauth = OAUTH_TOKENS.write();
                        *oauth = Some(tokens);
                    }
                }

                 if let Some(session_json) = store.get("firebase_session") {
                     if let Ok(session) =
                         serde_json::from_value::<FirebaseSession>(session_json.clone())
                     {
                         println!("Loaded Firebase session from storage");
                         {
                             let mut guard = FIREBASE_SESSION.write();
                             *guard = Some(session.clone());
                         }
                         emit_user_session(Some(session.user.clone()));
                     }
                 }
            }

            async_runtime::spawn(async {
                if let Err(err) = ensure_google_oauth_config_loaded().await {
                    eprintln!("Failed to preload Google OAuth config: {}", err);
                }
            });

            // Enable screenshot protection and full-screen overlay by default
            #[cfg(target_os = "macos")]
            {
                use cocoa::appkit::NSApplication;
                use cocoa::base::{nil, NO};

                // Set application activation policy to Accessory (non-activating)
                // NSApplicationActivationPolicyAccessory = 1
                unsafe {
                    let ns_app = NSApplication::sharedApplication(nil);
                    let _: () = msg_send![ns_app, setActivationPolicy: 1i64];
                }

                if let Some(window) = app.get_webview_window("main") {
                    use cocoa::base::id;

                    if let Ok(ns_window) = window.ns_window() {
                        let ns_window = ns_window as id;
                        unsafe {
                            // NSWindowSharingNone = 0 prevents the window from being captured
                            let _: () = msg_send![ns_window, setSharingType: 0u64];

                            // Set collection behavior to show over full-screen apps and ignore activation cycle
                            // NSWindowCollectionBehaviorCanJoinAllSpaces = 1 << 0
                            // NSWindowCollectionBehaviorFullScreenAuxiliary = 1 << 8
                            // NSWindowCollectionBehaviorIgnoresCycle = 1 << 6 (prevents window from being activated by window cycling)
                            let collection_behavior: u64 = (1 << 0) | (1 << 8) | (1 << 6);
                            let _: () = msg_send![ns_window, setCollectionBehavior: collection_behavior];

                            // Set window level to floating to keep it on top without activation
                            // NSFloatingWindowLevel = 3
                            let _: () = msg_send![ns_window, setLevel: 3i32];

                            // Prevent the window from hiding when it "deactivates"
                            let _: () = msg_send![ns_window, setHidesOnDeactivate: NO];

                            // Set style mask to include non-activating panel behavior
                            // This prevents the window from becoming key when clicked
                            let current_style: u64 = msg_send![ns_window, styleMask];
                            // NSWindowStyleMaskNonactivatingPanel = 1 << 7
                            let new_style = current_style | (1 << 7);
                            let _: () = msg_send![ns_window, setStyleMask: new_style];
                        }
                    }
                }
            }

            // Enable screenshot protection and non-activating style by default on Windows
            #[cfg(target_os = "windows")]
            {
                if let Some(window) = app.get_webview_window("main") {
                    use windows::Win32::Foundation::HWND;
                    use windows::Win32::UI::WindowsAndMessaging::{
                        SetWindowDisplayAffinity, WDA_EXCLUDEFROMCAPTURE,
                        GetWindowLongW, SetWindowLongW, GWL_EXSTYLE, WS_EX_NOACTIVATE
                    };

                    if let Ok(hwnd_wrapper) = window.hwnd() {
                        let hwnd = HWND(hwnd_wrapper.0 as _);
                        unsafe {
                            // Enable screenshot protection
                            let _ = SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE);

                            // Set WS_EX_NOACTIVATE to prevent activation
                            let ex_style = GetWindowLongW(hwnd, GWL_EXSTYLE);
                            SetWindowLongW(hwnd, GWL_EXSTYLE, ex_style | WS_EX_NOACTIVATE.0 as i32);
                        }
                    }
                }
            }

            // Start the web server in a background thread
            let frontend_dir = resolve_frontend_dir(app);
            std::thread::spawn(move || {
                let rt = tokio::runtime::Runtime::new().unwrap();
                rt.block_on(start_server(frontend_dir));
            });

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            get_firebase_client_config,
            get_firebase_user,
            get_current_slide,
            get_current_notes,
            get_auth_status,
            get_granted_scopes,
            has_scope,
            set_google_oauth_config,
            start_login,
            logout,
            logout_firebase,
            refresh_notes,
            track_usage_event,
            set_window_opacity,
            get_window_opacity,
            set_screenshot_protection
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
// Tauri command to provide Firebase client config to the frontend
#[tauri::command]
fn get_firebase_client_config() -> FirebaseClientConfigResponse {
    firebase_client_config_response()
}

#[tauri::command]
fn get_firebase_user() -> FirebaseUserSessionResponse {
    let session = FIREBASE_SESSION.read();
    if let Some(ref s) = *session {
        FirebaseUserSessionResponse {
            authenticated: true,
            email: Some(s.user.email.clone()),
            display_name: s.user.display_name.clone(),
            photo_url: s.user.photo_url.clone(),
        }
    } else {
        FirebaseUserSessionResponse {
            authenticated: false,
            email: None,
            display_name: None,
            photo_url: None,
        }
    }
}

#[tauri::command]
async fn track_usage_event(usage_type: String) -> Result<(), String> {
    increment_usage_counter(&usage_type).await
}

#[tauri::command]
fn logout_firebase() -> Result<(), String> {
    clear_firebase_session();
    Ok(())
}

// Tauri command to set Google OAuth configuration fetched from Firestore
#[tauri::command]
fn set_google_oauth_config(client_id: String, client_secret: String) -> Result<(), String> {
    apply_google_oauth_config(&client_id, &client_secret)
}

fn apply_google_oauth_config(client_id: &str, client_secret: &str) -> Result<(), String> {
    let trimmed_id = client_id.trim();
    let trimmed_secret = client_secret.trim();
    if trimmed_id.is_empty() || trimmed_secret.is_empty() {
        return Err("Client ID and secret are required".to_string());
    }

    let mut config = GOOGLE_OAUTH_CONFIG.write();
    *config = Some(GoogleOAuthConfig {
        client_id: trimmed_id.to_string(),
        client_secret: trimmed_secret.to_string(),
    });

    println!("Google OAuth client updated");

    Ok(())
}

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname !== "/welcome") {
      return new Response("Not Found", { status: 404 });
    }

    if (request.method !== "POST") {
      return new Response("Method Not Allowed", {
        status: 405,
        headers: {
          Allow: "POST"
        }
      });
    }

    let payload;
    try {
      payload = await request.json();
    } catch (error) {
      console.log("welcome_payload_error", error?.message || "invalid_json");
      return new Response("Bad Request", { status: 400 });
    }

    console.log("welcome_payload", JSON.stringify(payload));

    return new Response("OK", { status: 200 });
  }
};

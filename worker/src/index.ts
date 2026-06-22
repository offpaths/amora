export default {
  async fetch(): Promise<Response> {
    return new Response("Amora API", { status: 200 });
  }
};

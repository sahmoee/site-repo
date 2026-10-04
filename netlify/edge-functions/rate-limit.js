// Limit POST submissions on pages with public forms. Netlify enforces
// the rate limit before this function runs; returning undefined continues
// to the normal static handler and redirect rules.
export default async () => {};

export const config = {
  path: ["/", "/support/", "/delete-data/", "/unsubscribe/"],
  method: "POST",
  rateLimit: {
    windowLimit: 20,
    windowSize: 60,
    aggregateBy: ["ip", "domain"],
  },
};

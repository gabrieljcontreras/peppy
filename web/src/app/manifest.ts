import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "peppy — track your protocol, understand your body",
    short_name: "peppy",
    description:
      "Log peptide protocols, daily check-ins, weight, and wearables. peppy connects the dots so you can see what's actually working.",
    start_url: "/",
    display: "standalone",
    background_color: "#FAF7F0",
    theme_color: "#FAF7F0",
    icons: [
      {
        src: "/icon-192x192.png",
        sizes: "192x192",
        type: "image/png",
      },
      {
        src: "/icon-512x512.png",
        sizes: "512x512",
        type: "image/png",
      },
    ],
  };
}

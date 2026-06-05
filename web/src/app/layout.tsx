import type { Metadata } from "next";
import { Plus_Jakarta_Sans, Fraunces, Nunito } from "next/font/google";
import "./globals.css";

const jakarta = Plus_Jakarta_Sans({
  variable: "--font-jakarta",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  display: "swap",
});

const fraunces = Fraunces({
  variable: "--font-fraunces",
  subsets: ["latin"],
  weight: ["400", "500", "600"],
  style: ["italic"],
  display: "swap",
});

const nunito = Nunito({
  variable: "--font-nunito",
  subsets: ["latin"],
  weight: ["800"],
  display: "swap",
});

export const metadata: Metadata = {
  title: {
    default: "peppy — track your peptide protocol, understand your body",
    template: "%s | peppy",
  },
  description:
    "peppy is the peptide protocol tracker that logs daily check-ins, weight, and wearables — so you can see what's actually working. Get peppy and take control of your health journey.",
  keywords: [
    "peppy",
    "get peppy",
    "peptide tracker",
    "peptide protocol",
    "health tracking",
    "peptide logging",
    "BPC-157",
    "wellness tracker",
  ],
  authors: [{ name: "peppy" }],
  creator: "peppy",
  metadataBase: new URL("https://get-peppy.com"),
  openGraph: {
    type: "website",
    locale: "en_US",
    url: "https://get-peppy.com",
    siteName: "peppy",
    title: "peppy — track your peptide protocol, understand your body",
    description:
      "Log peptide protocols, daily check-ins, weight, and wearables. peppy connects the dots so you can see what's actually working.",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "peppy — peptide protocol tracker",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "peppy — track your peptide protocol, understand your body",
    description:
      "Log peptide protocols, daily check-ins, weight, and wearables. peppy connects the dots so you can see what's actually working.",
    images: ["/og-image.png"],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html
      lang="en"
      className={`${jakarta.variable} ${fraunces.variable} ${nunito.variable} antialiased`}
    >
      <body className="min-h-screen bg-background text-foreground">
        {children}
      </body>
    </html>
  );
}

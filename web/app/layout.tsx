import type { Metadata } from "next";
import { Plus_Jakarta_Sans, Fraunces, Nunito } from "next/font/google";
import "./globals.css";

const plusJakarta = Plus_Jakarta_Sans({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-sans",
  display: "swap",
});

const fraunces = Fraunces({
  subsets: ["latin"],
  weight: ["500"],
  style: ["italic"],
  variable: "--font-serif",
  display: "swap",
});

const nunito = Nunito({
  subsets: ["latin"],
  weight: ["800"],
  variable: "--font-wordmark",
  display: "swap",
});

export const metadata: Metadata = {
  title: "peppy — track your protocol",
  description: "Log peptide protocols, track your response, and get personalized insights — all in one place.",
  keywords: ["peptide", "protocol", "tracking", "health", "wellness", "GLP-1", "weight loss"],
  authors: [{ name: "peppy" }],
  openGraph: {
    title: "peppy — track your protocol",
    description: "Log peptide protocols, track your response, and get personalized insights — all in one place.",
    type: "website",
    locale: "en_US",
  },
  twitter: {
    card: "summary_large_image",
    title: "peppy — track your protocol",
    description: "Log peptide protocols, track your response, and get personalized insights — all in one place.",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      data-scroll-behavior="smooth"
      className={`${plusJakarta.variable} ${fraunces.variable} ${nunito.variable}`}
    >
      <body className="min-h-screen flex flex-col bg-[var(--color-cream-100)] text-[var(--color-ink-900)] antialiased">
        {children}
      </body>
    </html>
  );
}

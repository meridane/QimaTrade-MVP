import type { Metadata } from "next";
import "./globals.css";
import GlobalActionLoader from "@/components/global-action-loader";

export const metadata: Metadata = {
  title: "QimaTrade MVP",
  description: "QimaTrade Marketplace MVP",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fr">
      <body>
        {children}
        <GlobalActionLoader />
      </body>
    </html>
  );
}

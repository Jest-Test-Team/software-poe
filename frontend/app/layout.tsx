import type { Metadata } from "next";
import Link from "next/link";
import "./globals.css";

export const metadata: Metadata = {
  title: "Software POE",
  description: "Post-occupancy evaluation for software architecture",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-slate-50 text-slate-900 antialiased">
        <header className="border-b border-slate-200 bg-white">
          <nav className="mx-auto flex max-w-5xl items-center gap-6 px-6 py-4">
            <Link href="/" className="font-semibold">
              Software POE
            </Link>
            <Link href="/" className="text-sm text-slate-600 hover:text-slate-900">
              Dashboard
            </Link>
            <Link href="/reviews" className="text-sm text-slate-600 hover:text-slate-900">
              Review queue
            </Link>
          </nav>
        </header>
        <main className="mx-auto max-w-5xl px-6 py-8">{children}</main>
      </body>
    </html>
  );
}

import { NextResponse } from "next/server";
import { defaultPool } from "@/lib/db";

export async function GET() {
  try {
    await defaultPool.query("SELECT 1");
    return NextResponse.json(
      { status: "ok", db: "awake", timestamp: new Date().toISOString() },
      { status: 200 }
    );
  } catch {
    return NextResponse.json(
      { status: "error", db: "asleep" },
      { status: 503 }
    );
  }
}

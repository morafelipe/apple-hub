import { NextResponse } from "next/server";
import { getRevenues } from "@/lib/revenues";

export async function GET() {
  try {
    const data = await getRevenues();
    return NextResponse.json({ success: true, ...data }, { status: 200 });
  } catch (error) {
    console.error("Error obteniendo ingresos:", error);
    return NextResponse.json(
      { error: "Error interno del servidor" },
      { status: 500 }
    );
  }
}
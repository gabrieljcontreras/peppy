type Ring = { color: string; pct: number; label: string };

export function Ring({ color, pct, label }: Ring) {
  const grad = `conic-gradient(${color} 0 ${pct}%, #eef0f4 ${pct}%)`;
  return (
    <div
      className="relative grid h-14 w-14 place-items-center rounded-full"
      style={{ background: grad }}
    >
      <span className="absolute inset-1.5 rounded-full bg-cream-50" />
      <span className="relative text-[13px] font-bold text-ink-900">{label}</span>
    </div>
  );
}

export function HeroPhone() {
  return (
    <div
      className="rounded-[38px] bg-ink-900 p-2 shadow-[0_32px_60px_-20px_rgba(30,32,38,0.35),0_8px_18px_-8px_rgba(30,32,38,0.25)]"
      style={{ width: 280, height: 560, transform: "rotate(-6deg) translateY(20px)" }}
    >
      <div className="flex h-full w-full flex-col gap-3 rounded-[30px] bg-cream-50 px-4 pt-5">
        <div className="flex justify-between text-[11px] font-semibold text-ink-900">
          <span>9:41</span>
          <span>•••</span>
        </div>
        <div className="text-[18px] font-semibold text-ink-900">Today, May 30</div>

        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="inline-block h-[18px] w-[18px] rounded-full bg-rust-500" />
            <small className="text-[12px] text-ink-500">Protocol active</small>
          </div>
          <span className="rounded-full bg-rust-500/15 px-2.5 py-0.5 text-[11px] font-semibold text-rust-700">
            Week 6
          </span>
        </div>

        <div className="mt-1 flex gap-2.5">
          <Ring color="var(--peppy-rust-500)" pct={68} label="-2.3" />
          <Ring color="var(--peppy-success)" pct={82} label="82%" />
        </div>

        <div className="mt-1 text-[13px] font-semibold text-ink-900">Weight trend</div>
        <div className="peppy-bargraph" />

        <div className="mt-auto flex items-center justify-between text-[11px] text-ink-500">
          <small>184.5 lbs</small>
          <small>7-day avg</small>
        </div>
      </div>
    </div>
  );
}

export function HeroWatch() {
  return (
    <div
      className="rounded-[44px] bg-ink-900 p-2 shadow-[0_32px_60px_-20px_rgba(30,32,38,0.35),0_8px_18px_-8px_rgba(30,32,38,0.25)]"
      style={{ width: 180, height: 220, transform: "rotate(4deg)" }}
    >
      <div className="flex h-full w-full flex-col rounded-[36px] bg-ink-900 p-4 text-cream-50">
        <div className="flex justify-between text-[11px] font-semibold">
          <span>May 30</span>
          <span>96%</span>
        </div>
        <div
          className="mt-2 grid aspect-square w-full place-items-center rounded-full"
          style={{
            background:
              "conic-gradient(from -90deg, var(--peppy-rust-500) 0 68%, #1c1d22 68%)",
          }}
        >
          <div className="grid aspect-square w-[70%] flex-col place-items-center rounded-full bg-ink-900">
            <div className="flex flex-col items-center">
              <b className="text-[18px] leading-none">68%</b>
              <small className="text-[10px] text-ink-300">Adherence</small>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

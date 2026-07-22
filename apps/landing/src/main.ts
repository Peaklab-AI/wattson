import "./style.css";

const clock = document.getElementById("mb-clock");

if (clock) {
  const formatMenuBarClock = (date: Date) => {
    const weekday = date.toLocaleDateString("en-US", { weekday: "short" });
    const day = date.getDate();
    const month = date.toLocaleDateString("en-US", { month: "short" });
    const minutes = date.getMinutes().toString().padStart(2, "0");
    const hours = date.getHours() % 12 || 12;
    const ampm = date.getHours() >= 12 ? "pm" : "am";
    return `${weekday} ${day} ${month} ${hours}:${minutes} ${ampm}`;
  };

  const updateClock = () => {
    clock.textContent = formatMenuBarClock(new Date());
  };

  updateClock();
  setInterval(updateClock, 15_000);
}

const copyButton = document.getElementById("install-cmd-copy");
const installCmdText = document.getElementById("install-cmd-text");

if (copyButton && installCmdText) {
  copyButton.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(installCmdText.textContent ?? "");
    } catch {
      return;
    }
    copyButton.classList.add("is-copied");
    copyButton.setAttribute("aria-label", "Copied");
    window.setTimeout(() => {
      copyButton.classList.remove("is-copied");
      copyButton.setAttribute("aria-label", "Copy install command");
    }, 1500);
  });
}

const glow = document.getElementById("bg-glow");

if (glow && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
  let targetX = 0;
  let targetY = 0;
  let x = 0;
  let y = 0;

  window.addEventListener("pointermove", (event) => {
    targetX = event.clientX - window.innerWidth / 2;
    targetY = event.clientY - window.innerHeight / 2;
  });

  const animate = () => {
    x += (targetX - x) * 0.08;
    y += (targetY - y) * 0.08;
    glow.style.transform = `translate(${x}px, ${y}px)`;
    requestAnimationFrame(animate);
  };

  requestAnimationFrame(animate);
}

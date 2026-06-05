const glow = document.querySelector(".cursor-glow");
const reveals = document.querySelectorAll(".reveal");
const magneticItems = document.querySelectorAll(".magnet");
const burstItems = document.querySelectorAll(".burst");

window.addEventListener("pointermove", (event) => {
  glow.style.opacity = "1";
  glow.style.left = `${event.clientX}px`;
  glow.style.top = `${event.clientY}px`;
});

window.addEventListener("pointerleave", () => {
  glow.style.opacity = "0";
});

const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.16 }
);

reveals.forEach((item) => observer.observe(item));

magneticItems.forEach((item) => {
  item.addEventListener("pointerdown", () => item.classList.add("is-down"));
  item.addEventListener("pointerup", () => item.classList.remove("is-down"));
  item.addEventListener("pointerleave", () => item.classList.remove("is-down"));
});

burstItems.forEach((item) => {
  item.addEventListener("click", (event) => {
    for (let index = 0; index < 10; index += 1) {
      const dot = document.createElement("span");
      const angle = (Math.PI * 2 * index) / 10;
      const distance = 34 + Math.random() * 22;

      dot.className = "burst-dot";
      dot.style.left = `${event.clientX}px`;
      dot.style.top = `${event.clientY}px`;
      dot.style.setProperty("--x", `${Math.cos(angle) * distance}px`);
      dot.style.setProperty("--y", `${Math.sin(angle) * distance}px`);
      document.body.appendChild(dot);

      window.setTimeout(() => dot.remove(), 680);
    }
  });
});

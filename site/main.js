const revealItems = document.querySelectorAll(".reveal");
const pressableItems = document.querySelectorAll(".pressable");
const sparkleTargets = document.querySelectorAll(".sparkle-target");

const revealObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        revealObserver.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.14 }
);

revealItems.forEach((item) => revealObserver.observe(item));

pressableItems.forEach((item) => {
  item.addEventListener("pointerdown", () => item.classList.add("is-pressed"));
  item.addEventListener("pointerup", () => item.classList.remove("is-pressed"));
  item.addEventListener("pointerleave", () => item.classList.remove("is-pressed"));
});

sparkleTargets.forEach((target) => {
  target.addEventListener("click", (event) => {
    for (let index = 0; index < 8; index += 1) {
      const sparkle = document.createElement("span");
      const angle = (Math.PI * 2 * index) / 8;
      const distance = 28 + Math.random() * 20;

      sparkle.className = "sparkle";
      sparkle.style.left = `${event.clientX}px`;
      sparkle.style.top = `${event.clientY}px`;
      sparkle.style.setProperty("--dx", `${Math.cos(angle) * distance}px`);
      sparkle.style.setProperty("--dy", `${Math.sin(angle) * distance}px`);
      document.body.appendChild(sparkle);

      window.setTimeout(() => sparkle.remove(), 620);
    }
  });
});

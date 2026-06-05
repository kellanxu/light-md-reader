const revealItems = document.querySelectorAll(".reveal");
const pressableItems = document.querySelectorAll(".pressable");

const revealObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        revealObserver.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.16 }
);

revealItems.forEach((item) => revealObserver.observe(item));

pressableItems.forEach((item) => {
  item.addEventListener("pointerdown", () => item.classList.add("is-pressed"));
  item.addEventListener("pointerup", () => item.classList.remove("is-pressed"));
  item.addEventListener("pointerleave", () => item.classList.remove("is-pressed"));
});

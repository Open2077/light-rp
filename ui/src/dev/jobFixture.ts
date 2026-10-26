import type { JobCenterDialogPayload } from "@/bridge/protocol";

export function jobFixture(): JobCenterDialogPayload {
  return { kind: "jobcenter", spot: { id: "citycenter", name: "Job Center // City Center" }, paycheckMinutes: 30, jobs: [
    { name: "sanitation", label: "Sanitation", tag: "CITY SERVICES", grades: 4, entryGrade: { label: "Trainee", salary: 40 }, work: { raw:"Trash Bag",product:"Sorted Recyclables",collectCount:1,collectWeight:4,inputCount:1,outputCount:1,price:18 }, recruitment: {
      image: "img/jobs/sanitation.webp", icon: "trash-2", environment: "Street level", headline: "A cleaner city. One block at a time.",
      description: "Collect bags of waste, sort them into recyclables and sell your stock. No shift: work at your own pace and use your vehicle trunk.",
      steps: ["Collect weighted trash bags", "Sort waste into recyclables", "Sell your finished materials"],
    } },
    { name: "scrapper", label: "Scrapper", tag: "SALVAGE & RECYCLING", grades: 3, entryGrade: { label: "Salvage hand", salary: 45 }, work: { raw:"Scrap",product:"Salvaged Parts",collectCount:4,collectWeight:4,inputCount:4,outputCount:1,price:24 }, recruitment: {
      image: "img/jobs/scrapper.webp", icon: "hammer", environment: "Industrial yards", headline: "Find value in what the city leaves behind.",
      description: "Collect scrap, process reusable parts and sell them at the depot. No work order: transport heavy loads in your trunk.",
      steps: ["Collect scrap until your bag is full", "Process it into salvaged parts", "Sell parts at the depot"],
    } },
    { name: "ac_cleaner", label: "AC Cleaner", tag: "ROOFTOP MAINTENANCE", grades: 3, entryGrade: { label: "Maintenance trainee", salary: 50 }, route: { label: "Rooftop maintenance", reward: 260, stops: 3, estimate: "5–8 min", description: "Service rooftop cooling units and return your report." }, recruitment: {
      image: "img/jobs/ac-cleaner.webp", icon: "fan", environment: "Up on the rooftops", headline: "Keep Night City cool. Above the noise.",
      description: "Head up to the rooftops and service air-conditioning units. Clear the dust, clean the cooling equipment and move on to the next building.",
      steps: ["Reach the rooftop", "Clean the AC equipment", "Move to the next building"],
    } },
  ] };
}

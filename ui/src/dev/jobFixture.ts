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
    { name: "delivery", label: "Courier", tag: "FOOD & PARCEL DELIVERY", grades: 3, entryGrade: { label: "Runner", salary: 45 }, route: { label: "Delivery run", reward: 80, stops: 6, variable: true, orders: { min: 2, max: 3 }, estimate: "Random route · paid by distance", description: "Collect each order at its pickup point, then deliver them one by one." }, recruitment: {
      image: "img/jobs/delivery.webp", icon: "package", environment: "All over the city", headline: "Hot food, cold streets. Deliver before it cools.",
      description: "Collect orders at restaurants and depots, then deliver them to apartments and megabuildings. Every route is different; the longer it is, the more it pays. A vehicle helps.",
      steps: ["Collect the orders at their pickup points", "Deliver each one to its address", "Get paid by the distance covered"],
    } },
  ] };
}

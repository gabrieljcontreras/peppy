export const helpCategories = [
  "Accounts",
  "Protocols & Doses",
  "Check-ins",
  "Insights",
  "Notifications",
  "Data Export & Privacy",
  "Troubleshooting",
] as const;

export type HelpCategory = (typeof helpCategories)[number];

export type HelpEntry = {
  category: HelpCategory;
  question: string;
  answer: string;
  keywords: string[];
};

export const helpEntries: HelpEntry[] = [
  {
    category: "Accounts",
    question: "How do I change my password?",
    answer:
      "Use Settings > Security & Privacy > Change password. After a successful change, you’ll be signed out on every device and can sign back in with your new password.",
    keywords: ["password", "security", "sign out", "devices"],
  },
  {
    category: "Accounts",
    question: "How do I delete my account?",
    answer:
      "Use Settings > Security & Privacy > Delete account, confirm your password, and complete the irreversible confirmation. After confirmation, Peppy removes your account data from its active systems immediately. Limited backup and provider retention may continue under our disclosed operational terms.",
    keywords: ["delete account", "remove account", "deletion", "active systems"],
  },
  {
    category: "Protocols & Doses",
    question: "How do I add or update a dose?",
    answer:
      "Open your active protocol to add a dose or update a scheduled dose. Keep your protocol details current so your timeline and reminders reflect what you intend to track.",
    keywords: ["protocol", "dose", "schedule", "reminder"],
  },
  {
    category: "Check-ins",
    question: "What can I include in a check-in?",
    answer:
      "Check-ins can capture the wellness information you choose to log, including how you feel, symptoms, and notes. You control what you add.",
    keywords: ["check in", "symptoms", "notes", "wellness"],
  },
  {
    category: "Insights",
    question: "Are insights medical advice?",
    answer:
      "Peppy provides informational health tracking and AI-assisted insights. It does not diagnose, treat, prevent, or cure any condition and is not a substitute for professional medical advice. Consult a qualified healthcare professional before starting, stopping, or changing a peptide, medication, or treatment. Contact local emergency services for urgent help.",
    keywords: ["medical advice", "diagnosis", "treatment", "emergency"],
  },
  {
    category: "Notifications",
    question: "What information appears in notifications?",
    answer:
      "By default, notifications use generic text and do not include your protocol, dose, or other health details. You can separately opt in to show reminder details and turn that option off at any time in Notifications.",
    keywords: ["notifications", "privacy", "details", "reminders"],
  },
  {
    category: "Notifications",
    question: "What if I denied notification permission?",
    answer:
      "Your saved notification settings remain in place, but notifications are disabled at the iOS level. Open iOS Settings to allow notifications, then return to Peppy so it can reconcile your permission and reminders.",
    keywords: ["notifications", "permission", "denied", "iOS settings"],
  },
  {
    category: "Data Export & Privacy",
    question: "What can I export?",
    answer:
      "You can export available account, profile, and preference data, plus protocols and dose logs, check-ins, and insights. Exports are generated immediately as a PDF or CSV ZIP and are not kept as a durable server file.",
    keywords: ["export", "PDF", "CSV", "data", "privacy"],
  },
  {
    category: "Data Export & Privacy",
    question: "How is my information used for AI-assisted insights?",
    answer:
      "Relevant health and wellness data and free-text notes may be processed by a third-party AI processing service to generate informational insights. Direct identifiers are excluded from those inputs, and you control what information you choose to log and whether to use the feature.",
    keywords: ["AI", "privacy", "notes", "identifiers", "insights"],
  },
  {
    category: "Troubleshooting",
    question: "Why are my reminders not arriving?",
    answer:
      "Check that notifications are allowed in iOS Settings and that your reminder is enabled in Peppy. If the issue continues, revisit your notification settings or contact support.",
    keywords: ["notifications", "reminders", "troubleshooting", "support"],
  },
];

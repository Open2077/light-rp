/* Protocol error slugs -> short player-facing English. */
const TEXT: Record<string, string> = {
  unknown_number: "No neural line answers to that number.",
  unavailable: "Line unreachable. They are offline.",
  busy: "Line busy. Try again later.",
  in_call: "You are already in a call.",
  not_member: "You are not a member of this group.",
  not_owner: "Only the group owner can do that.",
  group_full: "This group is full.",
  invalid_body: "Messages must be 1 to 500 characters.",
  invalid_name: "That name is not valid.",
  invalid_number: "Numbers look like 555-0123.",
  rate_limited: "Too fast. Wait a moment.",
  no_line: "No neural line assigned yet.",
  database_unavailable: "Neural network storage is offline. Try again soon.",
  self: "You cannot do that with your own number.",
  handle_taken: "That handle is already taken.",
  invalid_handle: "Handles are 3 to 16 lowercase letters, digits or underscores.",
  unknown_handle: "No citizen answers to that handle.",
  unknown_post: "That scream is gone.",
  not_author: "Only the author can do that.",
  not_installed: "No Neural-Link implant detected.",
  ripperdoc_required: "Visit a ripperdoc to have a Neural-Link installed.",
  timeout: "The link timed out. Try again.",
  no_action: "That offer is no longer open.",
  already_answered: "Already answered.",
  unknown_message: "That message is gone.",
  map_unavailable: "The map did not take the pin.",
  unknown_recipient: "No neural line answers to that number.",
  gig_closed: "That job is closed.",
  gig_full: "The crew is full.",
  unknown: "Something went wrong on the link.",
};

export function errorText(slug: string | undefined | null): string {
  if (!slug) return TEXT.unknown!;
  return TEXT[slug] ?? TEXT.unknown!;
}

const END: Record<string, string> = {
  hangup: "Call ended",
  declined: "Call declined",
  busy: "Line busy",
  unavailable: "Unreachable",
  missed: "Missed call",
  no_answer: "No answer",
  dropped: "Link dropped",
};

export function endReasonText(reason: string): string { return END[reason] ?? "Call ended"; }

const TONES: Record<string, { label: string; className: string }> = {
  pending: { label: "Pending", className: "bg-tertiary-container/20 text-tertiary" },
  approved: { label: "Approved", className: "bg-ok-container/30 text-ok" },
  rejected: { label: "Rejected", className: "bg-error-container/30 text-error" },
  needs_more_information: { label: "Needs info", className: "bg-secondary-container/30 text-on-secondary-container" },
  withdrawn: { label: "Withdrawn", className: "bg-surface-container-highest text-on-surface-variant" },
  draft: { label: "Draft", className: "bg-surface-container-highest text-on-surface-variant" },
  published: { label: "Published", className: "bg-ok-container/30 text-ok" },
  cancelled: { label: "Cancelled", className: "bg-error-container/30 text-error" },
  completed: { label: "Completed", className: "bg-primary-container/30 text-primary" },
  archived: { label: "Archived", className: "bg-surface-container-highest text-on-surface-variant" },
  clean: { label: "Clean", className: "bg-ok-container/30 text-ok" },
  reported: { label: "Reported", className: "bg-secondary-container/30 text-on-secondary-container" },
  under_review: { label: "Under review", className: "bg-tertiary-container/20 text-tertiary" },
  blocked: { label: "Blocked", className: "bg-error-container/30 text-error" },
  restored: { label: "Restored", className: "bg-primary-container/30 text-primary" },
  open: { label: "Open", className: "bg-tertiary-container/20 text-tertiary" },
  resolved: { label: "Resolved", className: "bg-ok-container/30 text-ok" },
};

export function StatusBadge({ value }: { value: string }) {
  const tone = TONES[value] ?? {
    label: value,
    className: "bg-surface-container-highest text-on-surface-variant",
  };
  return (
    <span
      className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium capitalize ${tone.className}`}
    >
      {tone.label}
    </span>
  );
}
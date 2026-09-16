/// Organizer application as returned by the backend DTO
/// (`OrganizerApplicationDTO`). Status is one of `pending`, `approved` or
/// `rejected`.
class OrganizerApplication {
  const OrganizerApplication({
    required this.id,
    required this.requestedName,
    required this.requestedSlug,
    required this.bio,
    required this.status,
    this.reviewNotes = '',
    required this.createdAt,
  });

  final String id;
  final String requestedName;
  final String requestedSlug;
  final String bio;
  final String status;
  final String reviewNotes;
  final DateTime createdAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory OrganizerApplication.fromJson(Map<String, dynamic> json) {
    return OrganizerApplication(
      id: json['id'] as String? ?? '',
      requestedName: json['requested_name'] as String? ?? '',
      requestedSlug: json['requested_slug'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      reviewNotes: json['review_notes'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
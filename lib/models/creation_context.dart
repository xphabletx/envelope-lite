/// Tracks the nested creation state when creating binders and envelopes.
///
/// This context is passed down through nested creation flows to maintain
/// preselection state. For example:
/// - Creating envelope -> Creating binder for that envelope -> Creating envelope for that binder
/// - Creating binder -> Creating envelope for that binder -> Creating binder for that envelope
class CreationContext {
  /// The name of the binder being created (if we're in a binder creation flow)
  final String? pendingBinderName;

  /// The ID of an existing binder that should be preselected (if creating an envelope)
  final String? preselectedBinderId;

  /// The name of the envelope being created (if we're in an envelope creation flow)
  final String? pendingEnvelopeName;

  const CreationContext({
    this.pendingBinderName,
    this.preselectedBinderId,
    this.pendingEnvelopeName,
  });

  /// Create a context for when we're creating a binder inside an envelope creator
  /// The envelope name is carried forward so it can be shown as a selectable option
  CreationContext.forBinderInsideEnvelope(String envelopeName)
      : pendingEnvelopeName = envelopeName,
        pendingBinderName = null,
        preselectedBinderId = null;

  /// Create a context for when we're creating an envelope inside a binder creator
  /// The binder name is carried forward so it can be shown as preselected
  CreationContext.forEnvelopeInsideBinder(String binderName)
      : pendingBinderName = binderName,
        pendingEnvelopeName = null,
        preselectedBinderId = null;

  /// Create a context for when we're creating an envelope with a preselected existing binder
  CreationContext.withPreselectedBinder(String binderId)
      : preselectedBinderId = binderId,
        pendingBinderName = null,
        pendingEnvelopeName = null;

  /// Create a context for when we return from creating a binder (with an ID)
  /// and need to create an envelope for it
  CreationContext withCreatedBinder(String binderId) {
    return CreationContext(
      preselectedBinderId: binderId,
      pendingBinderName: null,
      pendingEnvelopeName: pendingEnvelopeName,
    );
  }

  /// Create a context for when we return from creating an envelope
  /// and need to select it in a binder
  CreationContext withCreatedEnvelope(String envelopeName) {
    return CreationContext(
      pendingEnvelopeName: envelopeName,
      preselectedBinderId: preselectedBinderId,
      pendingBinderName: null,
    );
  }

  /// Check if we have a pending envelope that should be shown in binder selection
  bool get hasPendingEnvelope =>
      pendingEnvelopeName != null && pendingEnvelopeName!.isNotEmpty;

  /// Check if we have a pending binder that should be shown/preselected in envelope creation
  bool get hasPendingBinder =>
      pendingBinderName != null && pendingBinderName!.isNotEmpty;

  /// Check if we have a preselected binder ID
  bool get hasPreselectedBinder =>
      preselectedBinderId != null && preselectedBinderId!.isNotEmpty;

  @override
  String toString() {
    return 'CreationContext(pendingBinderName: $pendingBinderName, '
        'preselectedBinderId: $preselectedBinderId, '
        'pendingEnvelopeName: $pendingEnvelopeName)';
  }
}

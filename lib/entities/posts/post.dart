import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:mooncake/entities/entities.dart';

part 'post.g.dart';

/// Represents a generic post
@immutable
@JsonSerializable(explicitToJson: true)
class Post extends Equatable implements Comparable<Post> {
  /// Represents the date format that should be used to format and parse
  /// post-related date values.
  static const DATE_FORMAT = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";

  /// Identifier used to reference posts status value.
  static const STATUS_VALUE_FIELD = "status.value";

  /// Identifier used to reference the data associated to the post status.
  static const STATUS_DATA_FIELD = "status.data";

  /// Identifier used to reference the posts' parent id.
  static const PARENT_ID_FIELD = "parent_id";

  /// Identifier used to reference the post creation date.
  static const DATE_FIELD = "created";

  /// Identifier used to reference post ids.
  static const ID_FIELD = "id";

  /// Identifier used to reference the hidden field or not.
  static const HIDDEN_FIELD = "hidden";

  /// Returns the current date and time in UTC time zone, formatted as
  /// it should be to be used as a post creation date or last edit date.
  static String getDateStringNow() {
    final formatter = DateFormat(DATE_FORMAT);
    return formatter.format(DateTime.now().toUtc());
  }

  @JsonKey(name: ID_FIELD)
  final String id;

  @JsonKey(name: PARENT_ID_FIELD, nullable: true)
  final String parentId;

  @JsonKey(name: "message")
  final String message;

  /// RFC3339-formatted creation date
  @JsonKey(name: DATE_FIELD)
  final String created;

  @JsonKey(name: "last_edited")
  final String lastEdited;

  @JsonKey(name: "allows_comments")
  final bool allowsComments;

  @JsonKey(name: "subspace")
  final String subspace;

  @JsonKey(name: "user")
  final User owner;

  @JsonKey(name: "optional_data", defaultValue: {})
  final Map<String, String> optionalData;

  @JsonKey(name: "media", defaultValue: [])
  final List<PostMedia> medias;

  @JsonKey(name: "reactions", defaultValue: [])
  final List<Reaction> reactions;

  @JsonKey(name: "children", defaultValue: [])
  final List<String> commentsIds;

  /// Tells if the post has been synced with the blockchain or not
  @JsonKey(name: "status", fromJson: _postStatusFromJson)
  final PostStatus status;

  /// Static method used to implement a custom deserialization of posts.
  static PostStatus _postStatusFromJson(Map<String, dynamic> json) {
    return json == null
        ? PostStatus(value: PostStatusValue.TX_SUCCESSFULL)
        : PostStatus.fromJson(json);
  }

  /// Tells whether or not the post has been hidden from the user.
  @JsonKey(name: HIDDEN_FIELD, defaultValue: false)
  final bool hidden;

  Post({
    @required this.id,
    this.parentId = "0",
    @required this.message,
    @required this.created,
    this.lastEdited,
    this.allowsComments = false,
    @required this.subspace,
    this.optionalData = const {},
    @required this.owner,
    List<PostMedia> medias = const [],
    List<Reaction> reactions = const [],
    List<String> commentsIds = const [],
    this.status = const PostStatus(value: PostStatusValue.STORED_LOCALLY),
    this.hidden = false,
  })  : assert(id != null),
        assert(message != null && message.isNotEmpty),
        assert(created != null),
        assert(subspace != null),
        assert(owner != null),
        this.medias = medias ?? [],
        this.reactions = reactions ?? [],
        this.reactionsCount = groupBy<Reaction, String>(
          (reactions ?? []).where((r) => !r.isLike).toList(),
          (r) => r.rune,
        ).map((rune, reactions) => MapEntry(reactions[0], reactions.length)),
        this.commentsIds = commentsIds ?? [];

  /// Returns the posts' data as a [DateTime] object.
  DateTime get dateTime {
    return DateTime.parse(created);
  }

  /// Tells if this post has a valid parent post or not.
  bool get hasParent {
    return parentId != null && parentId.trim().isNotEmpty && parentId != "0";
  }

  /// Returns only the list of images.
  List<PostMedia> get images {
    return medias?.where((element) => element.isImage)?.toList() ?? [];
  }

  /// Tells whether or not it contains local medias.
  bool get containsLocalMedias {
    return medias.any((media) => media.isLocal);
  }

  /// Contains a list of all the reactions and the respective count.
  final Map<Reaction, int> reactionsCount;

  /// Returns the list of all the likes that have been added.
  List<Reaction> get likes {
    return reactions?.where((reaction) => reaction.isLike)?.toList() ?? [];
  }

  /// Returns a new [Post] having the same data as `this` one, but
  /// with the specified data replaced.
  Post copyWith({
    PostStatus status,
    String parentId,
    String message,
    String created,
    String lastEdited,
    bool allowsComments,
    String subspace,
    Map<String, String> optionalData,
    String owner,
    List<PostMedia> medias,
    List<Reaction> reactions,
    List<String> commentsIds,
    bool hidden,
  }) {
    return Post(
      status: status ?? this.status,
      id: this.id,
      parentId: parentId ?? this.parentId,
      message: message ?? this.message,
      created: created ?? this.created,
      lastEdited: lastEdited ?? this.lastEdited,
      allowsComments: allowsComments ?? this.allowsComments,
      subspace: subspace ?? this.subspace,
      optionalData: optionalData ?? this.optionalData,
      owner: owner ?? this.owner,
      medias: medias ?? this.medias,
      reactions: reactions ?? this.reactions,
      commentsIds: commentsIds ?? this.commentsIds,
      hidden: hidden ?? this.hidden,
    );
  }

  @override
  int compareTo(Post other) {
    return created.compareTo(other.created);
  }

  @override
  List<Object> get props {
    return [
      this.id,
      this.parentId,
      this.message,
      this.created,
      this.lastEdited,
      this.allowsComments,
      this.subspace,
      this.owner,
      this.optionalData,
      this.medias,
      this.reactions,
      this.commentsIds,
      this.status,
      this.hidden,
    ];
  }

  @override
  String toString() {
    return 'Post { id: $id, status: $status }';
  }

  static Post fromJson(Map<String, dynamic> json) {
    return _$PostFromJson(json);
  }

  static Map<String, dynamic> asJson(Post post) {
    return post.toJson();
  }

  Map<String, dynamic> toJson() {
    return _$PostToJson(this);
  }
}
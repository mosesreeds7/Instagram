import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instegram/data/models/user_personal_info.dart';

class Post {
  // TODO it's for now (WhoLikes)
  String datePublished;
  String caption;
  String postImageUrl;
  String publisherId;
  String postUid;
  int numbersOfComments;
  List<dynamic> likes;
  UserPersonalInfo? publisherInfo;

  Post({
    required this.datePublished,
    required this.publisherId,
    this.publisherInfo,
    this.postUid = "",
    this.postImageUrl = "",
    this.caption = "",
    required this.numbersOfComments,
    required this.likes,
  });

  static Post fromSnap(QueryDocumentSnapshot<Map<String, dynamic>> snap) {
    return Post(
      caption: snap["caption"],
      datePublished: snap["datePublished"],
      postImageUrl: snap["postImageUrl"],
      publisherId: snap["publisherId"],
      postUid: snap["postUid"],
      likes: snap["likes"],
      numbersOfComments: snap["numbersOfComments"],
    );
  }

  static Post fromJson(DocumentSnapshot<Map<String, dynamic>> snap) {
    return Post(
      caption: snap["caption"],
      datePublished: snap["datePublished"],
      postImageUrl: snap["postImageUrl"],
      publisherId: snap["publisherId"],
      numbersOfComments: snap["numbersOfComments"],
      postUid: snap["postUid"],
      likes: snap["likes"],
    );
  }

  Map<String, dynamic> toMap() => {
        'caption': caption,
        "datePublished": datePublished,
        "postImageUrl": postImageUrl,
        "publisherId": publisherId,
        'numbersOfComments': numbersOfComments,
        'postUid': postUid,
        'likes': likes,
        'publisherInfo': publisherInfo,
      };
}

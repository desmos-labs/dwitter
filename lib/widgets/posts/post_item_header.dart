import 'package:desmosdemo/models/models.dart';
import 'package:flutter/material.dart';

/// Contains the info that are shown on top of a [PostItem]. The following
/// data are :
/// - the owner o the post
/// - the block height at which the post has been created
///
/// TODO: Add the username (maybe using Starnames?)
class PostItemHeader extends StatelessWidget {
  final Post post;

  PostItemHeader({
    @required this.post,
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          post.owner.hasUsername ? post.owner.username : post.owner.address,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
        ),
      ],
    );
  }
}
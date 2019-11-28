import 'package:desmosdemo/blocs/blocs.dart';
import 'package:desmosdemo/keys.dart';
import 'package:desmosdemo/screens/screens.dart';
import 'package:desmosdemo/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Represents a list of [Post] objects.
/// It simply builds a list using the [ListView.separated] builder
/// and the [PostItem] class as the object representing each post.
class Posts extends StatelessWidget {
  Posts({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PostsBloc, PostsState>(
      builder: (context, state) {
        if (state is PostsLoading) {
          return LoadingIndicator(key: PostsKeys.postsLoading);
        } else if (state is PostsLoaded) {
          final posts = state.posts.where((p) => !p.hasParent).toList();
          return ListView.separated(
            key: PostsKeys.postsList,
            itemCount: posts.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostItem(
                postId: post.id,
                onTap: () async => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DetailsScreen(postId: post.id),
                  ),
                ),
              );
            },
          );
        } else {
          return Container(key: PostsKeys.postsEmptyContainer);
        }
      },
    );
  }
}
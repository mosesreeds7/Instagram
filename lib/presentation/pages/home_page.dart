import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instegram/core/resources/color_manager.dart';
import 'package:instegram/core/resources/strings_manager.dart';
import 'package:instegram/data/models/post.dart';
import 'package:instegram/presentation/cubit/StoryCubit/story_cubit.dart';
import 'package:instegram/presentation/cubit/postInfoCubit/post_cubit.dart';
import 'package:instegram/presentation/cubit/postInfoCubit/specific_users_posts_cubit.dart';
import 'package:instegram/presentation/pages/story_config.dart';
import 'package:instegram/presentation/widgets/custom_app_bar.dart';
import 'package:instegram/presentation/widgets/post_list_view.dart';
import 'package:instegram/presentation/widgets/smart_refresher.dart';
import 'package:instegram/presentation/widgets/stroy_page.dart';
import 'package:instegram/presentation/widgets/toast_show.dart';
import 'package:inview_notifier_list/inview_notifier_list.dart';
import '../../data/models/user_personal_info.dart';
import '../cubit/firestoreUserInfoCubit/user_info_cubit.dart';
import '../widgets/circle_avatar_of_profile_image.dart';

class HomeScreen extends StatefulWidget {
  final String userId;

  const HomeScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool rebuild = true;
  bool loadingPosts = true;
  bool reLoadData = false;
  UserPersonalInfo? personalInfo;

  Future<void> getData() async {
    reLoadData = false;
    FirestoreUserInfoCubit userCubit =
        BlocProvider.of<FirestoreUserInfoCubit>(context, listen: false);
    await userCubit.getUserInfo(widget.userId, true);
    personalInfo = userCubit.myPersonalInfo;

    List usersIds = personalInfo!.followedPeople + personalInfo!.followerPeople;

    SpecificUsersPostsCubit usersPostsCubit =
        BlocProvider.of<SpecificUsersPostsCubit>(context, listen: false);

    await usersPostsCubit.getSpecificUsersPostsInfo(usersIds: usersIds);

    List usersPostsIds = usersPostsCubit.usersPostsInfo;

    List postsIds = usersPostsIds + personalInfo!.posts;

    PostCubit postCubit = PostCubit.get(context);
    await postCubit
        .getPostsInfo(postsIds: postsIds, isThatForMyPosts: true)
        .then((value) {
      Future.delayed(Duration.zero, () {
        setState(() {});
      });
      reLoadData = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bodyHeight = mediaQuery.size.height -
        AppBar().preferredSize.height -
        mediaQuery.padding.top;
    if (rebuild) {
      getData();
      rebuild = false;
    }
    return Scaffold(
      appBar: customAppBar(),
      body: SmarterRefresh(
        onRefreshData: getData,
        smartRefresherChild: blocBuilder(bodyHeight),
      ),
    );
  }

  BlocBuilder<PostCubit, PostState> blocBuilder(double bodyHeight) {
    return BlocBuilder<PostCubit, PostState>(
      buildWhen: (previous, current) {
        if (reLoadData && current is CubitMyPersonalPostsLoaded) {
          reLoadData = false;
          return true;
        }

        if (previous != current && current is CubitMyPersonalPostsLoaded) {
          return true;
        }
        if (previous != current && current is CubitPostFailed) {
          return true;
        }
        return false;
      },
      builder: (BuildContext context, PostState state) {
        if (state is CubitMyPersonalPostsLoaded) {
          return inViewNotifier(state, bodyHeight);
        } else if (state is CubitPostFailed) {
          ToastShow.toastStateError(state);
          return const Center(child: Text(StringsManager.noPosts));
        } else {
          return circularProgress();
        }
      },
    );
  }

  Center circularProgress() {
    return const Center(
      child: CircularProgressIndicator(
          strokeWidth: 1.5, color: ColorManager.black54),
    );
  }

  SingleChildScrollView inViewNotifier(
      CubitMyPersonalPostsLoaded state, double bodyHeight) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: InViewNotifierList(
        primary: false,
        scrollDirection: Axis.vertical,
        initialInViewIds: const ['0'],
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        isInViewPortCondition:
            (double deltaTop, double deltaBottom, double viewPortDimension) {
          return deltaTop < (0.5 * viewPortDimension) &&
              deltaBottom > (0.5 * viewPortDimension);
        },
        itemCount: state.postsInfo.length,
        builder: (BuildContext context, int index) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 0.5),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return InViewNotifierWidget(
                  id: '$index',
                  builder: (_, bool isInView, __) {
                    if (isInView) {}
                    return columnOfWidgets(bodyHeight, state.postsInfo, index);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget columnOfWidgets(double bodyHeight, List<Post> postsInfo, int index) {
    return Column(
      children: [
        if (index == 0) storiesLines(bodyHeight),
        const Divider(thickness: 0.5),
        posts(postsInfo[index]),
      ],
    );
  }

  Widget posts(Post postInfo) {
    return ImageList(
      postInfo: postInfo,
      // isVideoInView: isVideoInView,
    );
  }

  createNewStory() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      File photo = File(image.path);
      await Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(
          builder: (context) => NewStoryPage(storyImage: photo),
          maintainState: false));
      setState(() {
        reLoadData = true;
      });
    }
  }

  Widget storiesLines(double bodyHeight) {
    List<dynamic> usersStoriesIds =
    personalInfo!.followedPeople+ personalInfo!.followerPeople ;
    return BlocBuilder<StoryCubit, StoryState>(
      bloc: StoryCubit.get(context)
        ..getStoriesInfo(
            usersIds: usersStoriesIds, myPersonalInfo: personalInfo!),
      buildWhen: (previous, current) {
        if (reLoadData && current is CubitStoriesInfoLoaded) {
          reLoadData = false;
          return true;
        }

        if (previous != current && current is CubitStoriesInfoLoaded) {
          return true;
        }
        if (previous != current && current is CubitStoryFailed) {
          return true;
        }
        return false;
      },
      builder: (context, state) {
        if (state is CubitStoriesInfoLoaded) {
          List<UserPersonalInfo> storiesOwnersInfo = state.storiesOwnersInfo;
          return SizedBox(
            width: double.infinity,
            height: bodyHeight * 0.155,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // if (!storiesOwnersInfo.contains(personalInfo))
                  //   myOwnStory(context, storiesOwnersInfo, bodyHeight),
                  ListView.separated(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: storiesOwnersInfo.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const Divider(),
                    itemBuilder: (BuildContext context, int index) {
                      UserPersonalInfo publisherInfo = storiesOwnersInfo[index];
                      return Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context, rootNavigator: true)
                                  .push(CupertinoPageRoute(
                                maintainState: false,
                                builder: (context) => StoryPage(
                                    user: publisherInfo,
                                    storiesOwnersInfo: storiesOwnersInfo),
                              ));
                            },
                            child: CircleAvatarOfProfileImage(
                              circleAvatarName:
                                  publisherInfo.userId != personalInfo!.userId
                                      ? publisherInfo.name
                                      : "Your Story",
                              bodyHeight: bodyHeight,
                              thisForStoriesLine: true,
                              imageUrl: publisherInfo.profileImageUrl.isNotEmpty
                                  ? publisherInfo.profileImageUrl
                                  : '',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        } else if (state is CubitStoryFailed) {
          ToastShow.toastStateError(state);
          return const Center(child: Text(StringsManager.somethingWrong));
        } else {
          return Container();
        }
      },
    );
  }

  moveToStoryPage(
          List<UserPersonalInfo> storiesOwnersInfo, UserPersonalInfo user) =>
      Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(
        maintainState: false,
        builder: (context) =>
            StoryPage(user: user, storiesOwnersInfo: storiesOwnersInfo),
      ));

  Stack myOwnStory(BuildContext context,
      List<UserPersonalInfo> storiesOwnersInfo, double bodyHeight) {
    bool isPersonalStoriesEmpty = personalInfo!.stories.isEmpty;
    return Stack(
      children: [
        GestureDetector(
          onTap: () async {
            if (isPersonalStoriesEmpty) {
              await createNewStory();
            } else {
              moveToStoryPage(storiesOwnersInfo, personalInfo!);
            }
          },
          child: CircleAvatarOfProfileImage(
            circleAvatarName: "Your Story",
            bodyHeight: bodyHeight,
            thisForStoriesLine: true,
            bigCircleColor: !isPersonalStoriesEmpty,
            imageUrl: personalInfo!.profileImageUrl.isNotEmpty
                ? personalInfo!.profileImageUrl
                : '',
          ),
        ),
        if (isPersonalStoriesEmpty)
          const Positioned(
              top: 49,
              left: 50,
              right: 0,
              child: CircleAvatar(
                  radius: 9.5,
                  backgroundColor: ColorManager.white,
                  child: CircleAvatar(
                      radius: 8,
                      backgroundColor: ColorManager.blue,
                      child: Icon(
                        Icons.add,
                        size: 15,
                      )))),
      ],
    );
  }
}

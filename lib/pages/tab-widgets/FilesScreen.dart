import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/enums/listing-type.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final router=GoRouter.of(context);

    return SafeArea(
      child: Column(
        children: [
          Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 18.0,top: 24.0),
                child: Row(children: [
                  Text("My Storage",style: TextStyle(fontSize: 24,fontWeight: FontWeight.bold),),
                ],),
              ),
              Column(
                children: [
                  StorageTile(onTap: () => router.pushNamed('listing',queryParameters: {'type':ListingType.INTERNAL_STORAGE.value}),trailing: Text(0.toString(),style: const TextStyle(fontSize: 16),),leadingIconSvgPath: "assets/icons/hard-disk.svg",title: "Internal Storage",),
                  StorageTile(onTap: () => router.pushNamed('listing',queryParameters: {'type':ListingType.DOWNLOADS.value}),trailing: Text(0.toString(),style: const TextStyle(fontSize: 16),),leadingIconSvgPath: "assets/icons/downloads.svg",title: "Downloads",),
                  StorageTile(onTap: () => router.pushNamed('listing',queryParameters: {'type':ListingType.PROCESSED.value}),trailing: Text(0.toString(),style: const TextStyle(fontSize: 16),),leadingIconSvgPath: "assets/icons/folder-management.svg",title: "Processed Files",),
                ],
              )
            ],
          ),
          Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 18.0,top: 12.0),
                child: Row(children: [
                  Text("Cloud Storage",style: TextStyle(fontSize: 24,fontWeight: FontWeight.bold),),
                ],),
              ),
              Column(
                children: [
                  StorageTile(trailing: TextButton(onPressed: () {

                  }, child: const Text("Add Account")),leadingIconSvgPath: "assets/icons/google-drive.svg",title: "Google Drive",),
                  StorageTile(trailing: TextButton(onPressed: () {

                  }, child: const Text("Add Account")),leadingIconSvgPath: "assets/icons/drop-box.svg",title: "DropBox",),
                  StorageTile(trailing: TextButton(onPressed: () {

                  }, child: const Text("Add Account")),leadingIconSvgPath: "assets/icons/one-drive.svg",title: "OneDrive",),
                  StorageTile(trailing: TextButton(onPressed: () {

                  }, child: const Text("Add Account")),leadingIconSvgPath: "assets/icons/share-point.svg",title: "SharePoint",),
                ],
              )
            ],
          ),
          Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 18.0,top: 12.0),
                child: Row(children: [
                  Text("Others",style: TextStyle(fontSize: 24,fontWeight: FontWeight.bold),),
                ],),
              ),
              Column(
                children: [
                  StorageTile(trailing: Text(0.toString(),style: TextStyle(fontSize: 16),),
                    leadingIconSvgPath: "assets/icons/recycle-bin.svg",title: "Bin",),
                  ],
              )
            ],
          ),
        ],
      ),
  );
  }
}

class StorageTile extends StatelessWidget {
  final String leadingIconSvgPath;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;
  final EdgeInsets? padding;

  const StorageTile({
    super.key,
    this.onTap,
    this.padding,
    required this.leadingIconSvgPath,
    required this.title,
    required this.trailing
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.only(left: 16),
      child: ListTile(
        onTap:onTap,
        leading: SvgPicture.asset(leadingIconSvgPath,fit: BoxFit.contain,height: 28,),
        title: Text(title,style: TextStyle(fontSize: 18),),
        trailing: trailing,
      ),
    );
  }
}

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/extensions/string_etension.dart';
import 'package:pdf_craft/models/enums/user_access_permission.dart';
import 'package:pdf_craft/models/request/protect_pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProtectPdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  // const MergePdfView({super.key,required this.files,this.outFileName}):assert(files.length>1);
  const ProtectPdfView({super.key, required this.file, this.outFileName});

  @override
  State<ProtectPdfView> createState() => _ProtectPdfViewState();
}

class _ProtectPdfViewState extends State<ProtectPdfView>
    with ToolResultHandler, ToolViewMixin {
  late PdfBloc bloc=BlocProvider.of<PdfBloc>(context);
  final TextEditingController outFileNameC=TextEditingController();
  final TextEditingController _hintC=TextEditingController();
  String ownerPassword="";
  String userPassword="";
  // Passwords are masked by default; each field has its own show/hide toggle.
  bool _obscureOwner = true;
  bool _obscureUser = true;
  final List<UserAccessPermission> userPermissions=[];

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
    resetToolState([HttpStates.protectPdf]);
  }

  @override
  void dispose() {
    outFileNameC.dispose();
    _hintC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ToolStrings.name(context, 'protect')),
        elevation: 5,
      ),
      body: BlocConsumer<PdfBloc,PdfState>(
        buildWhen: (previous, current) => previous.httpStates[HttpStates.protectPdf]!=current.httpStates[HttpStates.protectPdf],
        listenWhen: (previous, current) => previous.httpStates[HttpStates.protectPdf]!=current.httpStates[HttpStates.protectPdf],
          // onDone rather than the default navigation: the hint has to be stored against the
          // produced file's name before we leave, so the unlock screen can offer it later.
          listener: (context, state) => handleToolState(
            state.httpStates[HttpStates.protectPdf],
            successMessage: L10n.current.toolDone,
            onDone: (savedFile) {
              final hint = _hintC.text.trim();
              if (hint.isNotEmpty) {
                SharedPreferences.getInstance().then((prefs) => prefs.setString(
                    'pwd_hint_${savedFile.path.split('/').last}', hint));
              }
              GoRouter.of(context).pushNamed(
                AppRoutes.pdfFilePreviewRoute.name,
                pathParameters: {'pdfFilePath': savedFile.path},
                queryParameters: const {'from': 'tool'},
              );
            },
          ),
          builder: (context, state) {
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Flex(
                    direction: Axis.vertical,
                    mainAxisSize: MainAxisSize.max,
                    children:[
                      // final Set<UserAccessPermission> userAccessPermissions;//empty means user has owner permission
                      Expanded(
                        child: SingleChildScrollView(child: Column(
                            children: [
                              TextFormField(keyboardType: TextInputType.text,
                                  decoration: InputDecoration(labelText: L10n.of(context).fileNameLabel,border: const OutlineInputBorder()),
                                  controller: outFileNameC),
                              const SizedBox(height: 16,),
                              TextFormField(
                                controller: _hintC,
                                decoration: InputDecoration(
                                  labelText: L10n.of(context).passwordHintOptional,
                                  hintText: L10n.of(context).passwordHintExample,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.lightbulb_outline),
                                ),
                              ),
                              const SizedBox(height: 16,),
                              // Both passwords were shown in plain text on a numeric keyboard, and the
                              // disabled button never said why. Now masked, full keyboard, and the
                              // 10-character rule is stated up front.
                              TextFormField(
                                keyboardType: TextInputType.visiblePassword,
                                obscureText: _obscureOwner,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  labelText: L10n.of(context).ownerPassword,
                                  helperText: L10n.of(context).atLeast10Chars,
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    tooltip: _obscureOwner ? L10n.of(context).showPassword : L10n.of(context).hidePassword,
                                    icon: Icon(_obscureOwner ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    onPressed: () => setState(() => _obscureOwner = !_obscureOwner),
                                  ),
                                ),
                                onChanged:(value) => setState(()=>ownerPassword=value),
                                validator:(value) {
                                  return value!=null && value.length>=10 ? null : L10n.of(context).min10Chars;
                                } ,),
                              const SizedBox(height: 16,),
                              TextFormField(
                                keyboardType: TextInputType.visiblePassword,
                                obscureText: _obscureUser,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  labelText: L10n.of(context).userPassword,
                                  helperText: L10n.of(context).atLeast10Chars,
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    tooltip: _obscureUser ? L10n.of(context).showPassword : L10n.of(context).hidePassword,
                                    icon: Icon(_obscureUser ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    onPressed: () => setState(() => _obscureUser = !_obscureUser),
                                  ),
                                ),
                                onChanged:(value) => setState(()=>userPassword=value),
                                validator:(value) {
                                  return value!=null && value.length>=10 ? null : L10n.of(context).min10Chars;
                                } ,),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 12,vertical: 16).copyWith(bottom: 10),
                                child: Flex(
                                  direction: Axis.vertical,
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    ...[Text(L10n.of(context).userPermissions,textAlign: TextAlign.center,style: const TextStyle(fontSize: 20,fontWeight: FontWeight.bold,decoration: TextDecoration.underline),),
                                      if(userPermissions.isEmpty) Text(L10n.of(context).willHaveOwnerPermissions)],
                                    ...UserAccessPermission.values.map((permission)=>Row(
                                      children: [
                                        Checkbox(tristate: false,value: userPermissions.contains(permission), onChanged: (hasPermission){
                                          setState(() {
                                            if(hasPermission==true) {
                                              userPermissions.add(permission);
                                            } else {
                                              userPermissions.removeWhere((permissionBit)=>permissionBit==permission);
                                            }
                                          });
                                        }),
                                        const SizedBox(width: 12,),
                                        Text(permission.name.capitalize()),
                                      ],
                                    )),
                                  ],
                                ),)])),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        child: FilledButton(onPressed: ownerPassword.length<10 || userPassword.length<10 ? null : _onProtectPdf, child: Text(ToolStrings.name(context, 'protect'))),
                      )
                    ],
                  ),
                ),
                processingOverlay(state.httpStates[HttpStates.protectPdf], label: L10n.of(context).procWorking),
              ],
            );
          },)
    );
  }

  void _onProtectPdf() async{
    final uploadFile = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => ProtectPdfEvent(protectPdf: ProtectPdf(outFileName: outFileNameC.text.isNotEmpty ? outFileNameC.text : "protected_file", ownerPassword: ownerPassword, userPassword: userPassword, userAccessPermissions: userPermissions.toSet(), file: uploadFile), cancelToken: cancelToken));
  }
}

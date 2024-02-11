import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:developer';

import '../constants/constants.dart';
import '../providers/chats_provider.dart';
import '../providers/models_provider.dart';
import '../services/assets_manager.dart';
import '../services/services.dart';
import '../widgets/chat_widget.dart';
import '../widgets/text_widget.dart';

import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _isTyping = false;
  late TextEditingController textEditingController;
  late ScrollController _listScrollController;
  late FocusNode focusNode;

  // Speech to text
  stt.SpeechToText _speech = stt.SpeechToText();
  String _lastWords = '';

  @override
  void initState() {
    _listScrollController = ScrollController();
    textEditingController = TextEditingController();
    focusNode = FocusNode();
    initSpeechState();
    super.initState();
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    textEditingController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  Future<void> initSpeechState() async {
    if (!_speech.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: TextWidget(
          label: "Speech recognition is not available on this device",
        ),
        backgroundColor: Colors.red,
      ));
      return;
    }
    await _speech.initialize(
      onError: (error) {
        log('Error: $error');
      },
      onStatus: (status) {
        log('Status: $status');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelsProvider = Provider.of<ModelsProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    return Scaffold(
      backgroundColor: AssetsManager.mainbg,
      appBar: AppBar(
        backgroundColor: AssetsManager.mainbg,
        elevation: 2,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(AssetsManager.openaiLogo),
        ),
        title: const Text("BlossomBlade",style: TextStyle(color: Colors.white),),
        // actions: [
        //   IconButton(
        //     onPressed: () async {
        //       await Services.showModalSheet(context: context);
        //     },
        //     icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
        //   ),
        // ],
      ),
      body: SafeArea(

        child: Column(
          children: [
            Flexible(
              child: ListView.builder(

                controller: _listScrollController,
                itemCount: chatProvider.getChatList.length,

                itemBuilder: (context, index) {
                  return ChatWidget(

                    msg: chatProvider.getChatList[index].msg,
                    chatIndex: chatProvider.getChatList[index].chatIndex,
                    shouldAnimate: chatProvider.getChatList.length - 1 == index,
                  );
                },
              ),
            ),
            if (_isTyping) ...[
              const SpinKitDancingSquare(
                color: Colors.white,
                size: 18,
              ),
            ],
            const SizedBox(
              height: 15,
            ),
            Material(
              color: cardColor,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(

                        focusNode: focusNode,
                        style: const TextStyle(color: Colors.white),
                        controller: textEditingController,
                        onSubmitted: (value) async {
                          await sendMessageFCT(
                              modelsProvider: modelsProvider,
                              chatProvider: chatProvider);
                        },
                        decoration: const InputDecoration.collapsed(
                            hintText: "How can I help you",
                            hintStyle: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await sendMessageFCT(
                            modelsProvider: modelsProvider,
                            chatProvider: chatProvider);
                      },
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: _isListening ? stopListening : startListening,
                      icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void scrollListToEND() {
    _listScrollController.animateTo(
        _listScrollController.position.maxScrollExtent,
        duration: const Duration(seconds: 2),
        curve: Curves.easeOut);
  }

  Future<void> sendMessageFCT(
      {required ModelsProvider modelsProvider,
        required ChatProvider chatProvider}) async {
    if (_isTyping) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TextWidget(
            label: "You can't send multiple messages at a time",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (textEditingController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TextWidget(
            label: "Please type a message",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    try {
      String msg = textEditingController.text;
      setState(() {
        _isTyping = true;
        chatProvider.addUserMessage(msg: msg);
        textEditingController.clear();
        focusNode.unfocus();
      });
      await chatProvider.sendMessageAndGetAnswers(
          msg: msg, chosenModelId: modelsProvider.getCurrentModel);
      setState(() {});
    } catch (error) {
      log("error $error");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: TextWidget(
          label: error.toString(),
        ),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() {
        scrollListToEND();
        _isTyping = false;
      });
    }
  }

  bool _isListening = false;

  void startListening() {
    _speech.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
          textEditingController.text = _lastWords;
        });
      },
    );
    setState(() => _isListening = true);
  }

  void stopListening() {
    _speech.stop();
    print(_lastWords);
    setState(() => _isListening = false);
  }
}


import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:recorder/ui/view_models/recorder_view_model.dart';

class RecorderScreen extends StatelessWidget {
  const RecorderScreen({super.key});

  RecorderController get controller => Get.put(RecorderController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            'Record yourself',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: controller.activatedIconColor.value,
              fontSize: 30.0,
            ),
          ),
        ),
        backgroundColor: Colors.black54,
      ),
      body: Container(
        color: Colors.black38,
        child: Column(
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                onTap: () => controller.toggleRecording(),
                child: Obx(
                  () => Icon(
                    Icons.mic,
                    size: 100.0,
                    color: controller.micColor.value,
                  ),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                GestureDetector(
                  onTap: () => controller.togglePlayback(),
                  child: Obx(
                    () => Icon(
                      controller.isPlaying.value
                          ? Icons.stop
                          : Icons.play_arrow,
                      size: 50.0,
                      color: controller.isPlaying.value
                          ? controller.playColor.value
                          : controller.activatedIconColor.value,
                    ),
                  ),
                ),
              ],
            ),
            Divider(color: Colors.white, thickness: 2.0),

            SizedBox(height: 20.0),

            Obx(() {
              print('Transcription updated: ${controller.transcription1.value}');
              return Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      controller.transcription1.value.isEmpty
                          ? "Speaker 1: Didn't say anything"
                          : 'Speaker 1: ${controller.transcription1.value}' + ' ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                  ),
                ),
              );
            }),
            

            SizedBox(height: 20.0),

            Divider(color: Colors.white, thickness: 2.0),

            SizedBox(height: 20.0),

            Obx(() {
              print('Transcription updated: ${controller.transcription2.value}');
              return Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      controller.transcription2.value.isEmpty
                          ? "Speaker 2: Didn't say anything"
                          : 'Speaker 2: ${controller.transcription2.value}' + ' ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                  ),
                ),
              );
            }),
            

            SizedBox(height: 20.0),
            
            Divider(color: Colors.white, thickness: 2.0),


            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                GestureDetector(
                  onTap: () => controller.togglePause(),
                  child: Obx(
                    () => Icon(
                      controller.isPaused.value
                          ? Icons.play_arrow
                          : Icons.pause,
                      size: 50.0,
                      color: controller.isPaused.value
                          ? controller.pauseColor.value
                          : controller.activatedIconColor.value,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => 
                    controller.resetValues(),
                  child: Icon(
                    Icons.restart_alt_rounded,
                    color: Colors.white,
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:flutter/material.dart';
import 'package:get/get_connect/http/src/request/request.dart';
import 'package:get/state_manager.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RecorderController extends GetxController{

void testFFmpeg() async {
  await FFmpegKit.execute('-version').then((session) {
    print('FFmpeg session completed');
  }).catchError((error) {
    print('FFmpeg error: $error');
  });
}

  Future<void> playAudioWithFFmpeg(String filePath) async {
  try {
    // FFmpeg command to play the audio file
    final command = '-i $filePath -f wav -';
    await FFmpegKit.execute(command);

    print("Playing audio from: $filePath");
  } catch (e) {
    print("Error playing audio: $e");
  }
}

Future<void> convertPCMToWAV(String pcmFilePath, String wavFilePath) async {
  
  testFFmpeg();

  try {
    // FFmpeg command to convert PCM to WAV
    final command = '-f s16le -ar 44100 -ac 1 -i $pcmFilePath $wavFilePath';
    await FFmpegKit.execute(command);

    print("Converted PCM to WAV: $wavFilePath");
  } catch (e) {
    print("Error converting PCM to WAV: $e");
  }
}


  // Add these new members for WebSocket streaming:
  WebSocketChannel? _wsChannel;
  bool _isWsConnected = false;

  // Your Speechmatics API key and endpoint
  final String _apiKey = 'TJsVj7ZfknBGwiXCLVBEmfzYInt7OylX';
  final String _wsUrl = 'wss://eu2.rt.speechmatics.com/v2';

  // Sequence number for audio chunks (optional, for tracking)
  int _seqNo = 0;

  var transcription1 = ''.obs; // Observable to hold transcription text
  var transcription2 = ''.obs; // Observable to hold transcription text
  var detectSpeaker = ''.obs; // Observable to hold selected speaker

  void resetValues(){
    transcription1.value = '';
    transcription2.value = '';
    detectSpeaker.value = '';
  }



   // Call this to start WebSocket connection and send StartRecognition
  Future<void> _startSpeechmaticsStream() async {
    try {
      print('Connecting to Speechmatics WebSocket...');
      _wsChannel = IOWebSocketChannel.connect(
        Uri.parse(_wsUrl),
        headers: {'Authorization': 'Bearer $_apiKey'},
      );

      _wsChannel!.stream.listen(_onWsMessage, onDone: () {
        print('WebSocket closed by server');
        _isWsConnected = false;
      }, onError: (error) {
        print('WebSocket error: $error');
        _isWsConnected = false;
      });

      // Send StartRecognition JSON message
     final startMsg = jsonEncode({
        "message": "StartRecognition",
        "transcription_config": {
          "language": "en", // Specify the language for transcription
          "operating_point": "enhanced",
          "diarization": "speaker",
          "speaker_diarization_config": {
          "max_speakers": 2,
          },
          "max_delay": 1,
          "max_delay_mode": "flexible",
          "enable_partials": true
        },
        "audio_format": {
          "type": "raw",
          "encoding": "pcm_s16le", // Correct encoding for 16-bit PCM
          "sample_rate": 44100 // Match your recording sample rate
        },
        
      });

      _wsChannel!.sink.add(startMsg);
      _isWsConnected = true;
      _seqNo = 0;

      print('Sent StartRecognition message');
    } catch (e) {
      print('Error connecting to Speechmatics: $e');
      _isWsConnected = false;
    }
  }

  // Call this to close WebSocket gracefully
  Future<void> _stopSpeechmaticsStream() async {
    if (_isWsConnected && _wsChannel != null) {
      // Send EndOfStream message
      final endMsg = jsonEncode(
        {
          "message": "EndOfStream",
          "last_seq_no": _seqNo,
          });
      _wsChannel!.sink.add(endMsg);
      await Future.delayed(Duration(seconds: 1)); // wait a bit for server response
      await _wsChannel!.sink.close();
      _isWsConnected = false;
      print('Closed Speechmatics WebSocket');
    }
  }

  // Handle incoming messages from Speechmatics server
  void _onWsMessage(dynamic message) {
  if (message is String) {
    final Map<String, dynamic> msg = jsonDecode(message);
    print('Speechmatics message: $msg');

    if (msg['message'] == 'Error') {
      print('Speechmatics error: ${msg['reason']}');
    } else if (msg['message'] == 'AddPartialTranscript' || msg['message'] == 'AddTranscript') {
      // Extract transcript from the `transcript` field or construct it from `results`
      if (msg['transcript'] != null && msg['transcript']!.isNotEmpty) {
        transcription1.value = msg['transcript'];
      } else if (msg['results'] != null) {
        final constructedTranscript = msg['results']
            .map((result) => result['alternatives']?[0]['content'])
            .where((content) => content != null)
            .join(' ');

        if (msg['results'] != null) {
        final speaker = msg['results']
            .map((result) => result['alternatives']?[0]['speaker'])
            .where((speaker) => speaker != null)
            .join(', ');
        detectSpeaker.value = speaker.isNotEmpty ? speaker : 'Unknown';

        if(speaker == 'S1'){
          transcription1.value += ' ' +constructedTranscript;
        }
        else if(speaker == 'S2'){
          transcription2.value +=  ' ' +constructedTranscript;
        }
      }
      }

      // Extract speaker information
      

      print('Speaker detected: ${detectSpeaker.value}');

      // Optionally log detailed results
      if (msg['results'] != null) {
        for (var result in msg['results']) {
          print('Result: ${result['alternatives']?[0]['content']} (type: ${result['type']}, confidence: ${result['alternatives']?[0]['confidence']}, speaker: ${result['alternatives']?[0]['speaker']})');
        }
      }
    } else if (msg['message'] == 'EndOfTranscript') {
      print('End of transcription received.');
      // Do not reset transcription value
    }
  } else if (message is List<int>) {
    print('Received binary message from server (${message.length} bytes)');
  }
}










  //var isRecording = false.obs;
  final record = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  final List<Uint8List> _audioChunks = [];
  String? _tempAudioPath;

  var isRecording = false.obs;
  var isPlaying = false.obs;
  var isPaused = false.obs;

  var isStarted = false.obs;
  var isStopped = true.obs;
  var micColor = Colors.red.obs;
  var activatedMicColor = Colors.green.obs;
  var pauseColor = Colors.black.obs;
  var playColor = Colors.black.obs;
  var activatedIconColor = Colors.green.obs;


  void toggleRecording() async{
    if(!isStarted.value){
      isStarted.value = true;
      isStopped.value = false;
      micColor.value = activatedMicColor.value;
      

      try{if (await record.hasPermission()) {

        _audioChunks.clear();


        // Start Speechmatics WebSocket streaming
          await _startSpeechmaticsStream();


      // ... or to stream
      final stream = await record.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1,
          ));

      
      print("RECORDING STARTED");

      // Listen to the stream
      stream.listen((data) {
        print('Audio data chunk received: ${data.length} bytes');
        _audioChunks.add(Uint8List.fromList(data));

        // Send PCM chunk as binary frame to Speechmatics
            if (_isWsConnected && _wsChannel != null) {
              _wsChannel!.sink.add(Uint8List.fromList(data));
              _seqNo++;
              // Optionally throttle sending if needed
            }

      });

      
      
      }
      }catch (e) {
        // Handle the error
        print("Error starting recording: $e");
      }
    }
      else{
        isStarted.value = false;
        isStopped.value = true;
        isPaused.value = false;
        micColor.value = Colors.red;
        pauseColor.value = Colors.black;
        // Stop recording...
        final path = await record.stop();

        // Stop Speechmatics streaming gracefully
      await _stopSpeechmaticsStream();


        //record.dispose();

        await _saveAudioToFile();
      }
    
    
  }
  

  Future<void> _saveAudioToFile() async {
  try {
    // Combine all chunks into a single buffer
    final totalLength = _audioChunks.fold(0, (sum, chunk) => sum + chunk.length);
    final bytes = Uint8List(totalLength);
    int offset = 0;

    for (var chunk in _audioChunks) {
      bytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    // Save PCM file
    final externalDir = await getExternalStorageDirectory();
    final pcmFilePath = '${externalDir!.path}/temp_recording.pcm';
    await File(pcmFilePath).writeAsBytes(bytes);

    // Convert PCM to WAV using FFmpeg
    final wavFilePath = '${externalDir.path}/temp_recording.wav';
    await convertPCMToWAV(pcmFilePath, wavFilePath);

    // Update the path to the WAV file for playback
    _tempAudioPath = wavFilePath;

    print("Sample Rate: 44100 Hz");
print("File size: ${File(_tempAudioPath!).lengthSync()} bytes");
print("File size: ${File(wavFilePath).lengthSync()} bytes");

    print("Audio saved to: $_tempAudioPath");
  } catch (e) {
    print("Error saving audio: $e");
  }
}
   
   Future<void> togglePlayback() async {
  try {
    if (isPlaying.value) {
      // Stop playback
      await _audioPlayer.stop();
      isPlaying.value = false;
      playColor.value = Colors.black;
    } else {
      // Start playback
      if (_tempAudioPath != null && await File(_tempAudioPath!).exists()) {
        isPlaying.value = true;
        playColor.value = activatedIconColor.value;
        print("Playing audio from: $_tempAudioPath");

        // Play the saved WAV file
        await _audioPlayer.play(
          DeviceFileSource(_tempAudioPath!),
          mode: PlayerMode.lowLatency,
        );

        // Reset when playback completes
        _audioPlayer.onPlayerComplete.listen((_) {
          isPlaying.value = false;
          playColor.value = Colors.black;
        });
      } else {
        print("No recorded audio found!");
      }
    }
  } catch (e) {
    print("Playback error: $e");
    isPlaying.value = false;
    playColor.value = Colors.black;
  }
}


  void togglePause(){
    if(isPaused.value && !isStopped.value){
      isPaused.value = false;
    }
    else if(!isPaused.value && !isStarted.value){
      return;
    }
    else{
      isPaused.value = true;
    }
  }


  @override
  void onClose() {

    record.dispose();
    _audioPlayer.dispose();
    super.onClose();
  }



}




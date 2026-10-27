// mqtt_service.dart -- тонкая обёртка над mqtt_client.
// Подписывается на smarthome/# и перекладывает JSON-пакеты в коллбек.
// Тот же протокол и схема топиков, что и у настольного проекта (курсовая).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart'; // MqttServerClient -- отдельная точка входа в 10.x

class MqttLink {
  final void Function(String topic, Map<String, dynamic> json) onJson;
  final void Function(String status) onStatus;

  MqttServerClient? _client;

  MqttLink({required this.onJson, required this.onStatus});

  bool get connected => _client?.connectionStatus?.state ==
      MqttConnectionState.connected;

  Future<void> connect(String host, int port) async {
    disconnect();
    onStatus('connecting');
    final id =
        'panel-${DateTime.now().millisecondsSinceEpoch % 1000000}';
    final client = MqttServerClient.withPort(host, id, port);
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.connectTimeoutPeriod = 5000;
    client.onConnected = () => onStatus('online');
    client.onDisconnected = () => onStatus('offline');
    client.onBadCertificate = (_) => false;

    try {
      await client.connect();
    } on SocketException catch (e) {
      onStatus('error');
      onStatus('err:сеть недоступна (${e.message})');
      return;
    } catch (e) {
      onStatus('error');
      onStatus('err:$host:$port -- $e');
      return;
    }
    if (client.connectionStatus!.state != MqttConnectionState.connected) {
      onStatus('error');
      onStatus('err:брокер отклонил подключение');
      return;
    }

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      if (c == null || c.isEmpty) return;
      final rec = c[0];
      final topic = rec.topic;
      final MqttPublishMessage pm = rec.payload as MqttPublishMessage;
      final text =
          MqttPublishPayload.bytesToStringAsString(pm.payload.message);
      try {
        final parsed = jsonDecode(text);
        if (parsed is Map<String, dynamic>) {
          onJson(topic, parsed);
        }
      } on FormatException {
        // статусные пакеты -- голая строка online/offline
        if (text.trim() == 'online' || text.trim() == 'offline') {
          onJson('$topic/raw', {'state': text.trim()});
        }
      }
    });

    client.subscribe('smarthome/#', MqttQos.atMostOnce);
    _client = client;
  }

  void publish(String topic, Map<String, dynamic> payload) {
    final client = _client;
    if (client == null || !connected) return;
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void disconnect() {
    final client = _client;
    _client = null;
    if (client != null) {
      try {
        client.disconnect();
      } catch (_) {
        // уже отключён -- не важно
      }
      onStatus('offline');
    }
  }
}

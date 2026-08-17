/// BT PeerId 解析工具类。
///
/// 逻辑来源: https://github.com/mayswind/angular-bittorrent-peerid
/// 将 JavaScript 实现移植为 Dart，支持 Az style / Shadow style / Mainline style / Simple 等主流客户端识别。
class PeerIdParser {
  PeerIdParser._();

  /// 解析 peerId 返回客户端名称与版本号。
  ///
  /// [rawPeerId] 为 Aria2 返回的 URL 编码 peerId。
  static PeerIdInfo parse(String rawPeerId) {
    if (rawPeerId.isEmpty) return const PeerIdInfo(client: 'unknown');

    // Aria2 peerId 是 URL 编码的，先解码为 Latin-1 字符串。
    // 注意：不能用 Uri.decodeComponent，因为 BT peerId 包含非 UTF-8 字节
    // （如 %1C、%B3），Uri.decodeComponent 会抛 FormatException。
    // 这里手动解码 %XX 为对应 code unit，与 JavaScript decodeURIComponent 行为一致。
    final peerId = _decodePercentEncoded(rawPeerId);
    if (peerId.isEmpty) return const PeerIdInfo(client: 'unknown');

    final buffer = _getUtf8Data(peerId);

    // Spoof 检测
    if (_isPossibleSpoofClient(peerId)) {
      var result = _decodeBitSpiritClient(peerId, buffer);
      if (result != null) return result;
      result = _decodeBitCometClient(peerId, buffer);
      if (result != null) return result;
      return const PeerIdInfo(client: 'BitSpirit?');
    }

    // Az style: -XX####-
    if (_isAzStyle(peerId)) {
      final clientName = _getAzStyleClientName(peerId);
      if (clientName != null) {
        final version = _getAzStyleClientVersion(clientName, peerId);
        return PeerIdInfo(client: clientName, version: version);
      }
    }

    // Shadow style: X####-
    if (_isShadowStyle(peerId)) {
      final clientName = _getShadowStyleClientName(peerId);
      if (clientName != null) {
        return PeerIdInfo(client: clientName);
      }
    }

    // Mainline style: M#-#-#--
    if (_isMainlineStyle(peerId)) {
      final clientName = _getMainlineStyleClientName(peerId);
      if (clientName != null) {
        return PeerIdInfo(client: clientName);
      }
    }

    // BitSpirit / BitComet (不论 spoof)
    var result = _decodeBitSpiritClient(peerId, buffer);
    if (result != null) return result;
    result = _decodeBitCometClient(peerId, buffer);
    if (result != null) return result;

    // Simple client 前缀匹配
    final simple = _getSimpleClient(peerId);
    if (simple != null) {
      return PeerIdInfo(client: simple.client, version: simple.version);
    }

    // 特殊格式
    result = _identifyAwkwardClient(peerId, buffer);
    if (result != null) return result;

    return const PeerIdInfo(client: 'unknown');
  }

  // ─── Az style 客户端映射 ──────────────────────────────────────

  static const _azStyleClients = <String, String>{
    'AG': 'Ares',
    'AN': 'Ares',
    'AR': 'Ares',
    'AV': 'Avicora',
    'AX': 'BitPump',
    'AT': 'Artemis',
    'AZ': 'Vuze',
    'BB': 'BitBuddy',
    'BC': 'BitComet',
    'BE': 'BitTorrent SDK',
    'BF': 'BitFlu',
    'BG': 'BTG',
    'bk': 'BitKitten (libtorrent)',
    'BR': 'BitRocket',
    'BS': 'BTSlave',
    'BT': 'BitTorrent',
    'BW': 'BitWombat',
    'BX': 'BittorrentX',
    'CB': 'Shareaza Plus',
    'CD': 'Enhanced CTorrent',
    'CT': 'CTorrent',
    'DE': 'Deluge',
    'DP': 'Propogate Data Client',
    'EB': 'EBit',
    'ES': 'Electric Sheep',
    'FC': 'FileCroc',
    'FG': 'FlashGet',
    'FT': 'FoxTorrent/RedSwoosh',
    'FX': 'Freebox BitTorrent',
    'GR': 'GetRight',
    'GS': 'GSTorrent',
    'HL': 'Halite',
    'HN': 'Hydranode',
    'KG': 'KGet',
    'KT': 'KTorrent',
    'LC': 'LeechCraft',
    'LH': 'LH-ABC',
    'LK': 'linkage',
    'LP': 'Lphant',
    'LT': 'libtorrent (Rasterbar)',
    'lt': 'libTorrent (Rakshasa)',
    'LW': 'LimeWire',
    'MO': 'MonoTorrent',
    'MP': 'MooPolice',
    'MR': 'Miro',
    'MT': 'MoonlightTorrent',
    'NE': 'BT Next Evolution',
    'NX': 'Net Transport',
    'OS': 'OneSwarm',
    'OT': 'OmegaTorrent',
    'PC': 'CacheLogic',
    'PD': 'Pando',
    'PE': 'PeerProject',
    'pX': 'pHoeniX',
    'PT': 'Popcorn Time',
    'qB': 'qBittorrent',
    'QD': 'qqdownload',
    'RT': 'Retriever',
    'RZ': 'RezTorrent',
    'S~': 'Shareaza alpha/beta',
    'SB': 'SwiftBit',
    'SD': 'Xunlei',
    'SG': 'GS Torrent',
    'SN': 'ShareNET',
    'SP': 'BitSpirit',
    'SS': 'SwarmScope',
    'ST': 'SymTorrent',
    'st': 'SharkTorrent',
    'SZ': 'Shareaza',
    'TG': 'Torrent GO',
    'TN': 'Torrent.NET',
    'TR': 'Transmission',
    'TS': 'TorrentStorm',
    'TT': 'TuoTu',
    'UL': 'uLeecher!',
    'UE': 'µTorrent Embedded',
    'UT': 'µTorrent',
    'UM': 'µTorrent Mac',
    'UW': 'µTorrent Web',
    'WD': 'WebTorrent Desktop',
    'WT': 'Bitlet',
    'WW': 'WebTorrent',
    'WY': 'FireTorrent',
    'VG': 'Vagaa',
    'XL': 'Xunlei',
    'XT': 'XanTorrent',
    'XF': 'Xfplay',
    'XX': 'XTorrent',
    'XC': 'XTorrent',
    'ZT': 'ZipTorrent',
    '7T': 'aTorrent',
    'ZO': 'Zona',
  };

  // ─── Shadow style 客户端映射 ─────────────────────────────────

  static const _shadowStyleClients = <String, String>{
    'A': 'ABC',
    'O': 'Osprey Permaseed',
    'Q': 'BTQueue',
    'R': 'Tribler',
    'S': 'Shad0w',
    'T': 'BitTornado',
    'U': 'UPnP NAT',
  };

  // ─── Mainline style 客户端映射 ────────────────────────────────

  static const _mainlineStyleClients = <String, String>{
    'M': 'Mainline',
    'Q': 'Queen Bee',
  };

  // ─── Simple clients（前缀匹配，无版本号或自定义版本）──────────

  static const _simpleClients = <_SimpleClient>[
    _SimpleClient('µTorrent', '1.7.0 RC', '-UT170-'),
    _SimpleClient('Azureus', '1', 'Azureus'),
    _SimpleClient('Aria2', null, '-aria2-'),
    _SimpleClient('BitTorrent Plus!', 'II', 'PRC.P---'),
    _SimpleClient('BitTorrent Plus!', null, 'P87.P---'),
    _SimpleClient('BitTorrent Plus!', null, 'S587Plus'),
    _SimpleClient('BitTyrant (Azureus Mod)', null, 'AZ2500BT'),
    _SimpleClient('Blizzard Downloader', null, 'BLZ'),
    _SimpleClient('MediaGet', '1', '-MG1'),
    _SimpleClient('MediaGet', '2.1', '-MG21'),
    _SimpleClient('MLdonkey', null, '-ML'),
    _SimpleClient('BitSpirit', null, 'BS'),
    _SimpleClient('XBT', null, 'XBT'),
    _SimpleClient('Tixati', null, 'TIX'),
    _SimpleClient('folx', null, '-FL'),
    _SimpleClient('µTorrent Mac', null, '-UM'),
    _SimpleClient('µTorrent', null, '-UT'),
    _SimpleClient('Opera', null, 'OP'),
    _SimpleClient('Opera', null, 'O'),
    _SimpleClient('Burst!', null, 'Mbrst'),
    _SimpleClient('TurboBT', null, 'turbobt'),
    _SimpleClient('BT Protocol Daemon', null, 'btpd'),
    _SimpleClient('Limewire', null, 'LIME'),
    _SimpleClient('Pando', null, 'Pando'),
    _SimpleClient('QVOD', null, 'QVOD'),
  ];

  // ─── 风格检测 ────────────────────────────────────────────────

  /// Az style: 第1字符 `-`，第8字符 `-`（或特殊两字符前缀）。
  static bool _isAzStyle(String peerId) {
    if (peerId[0] != '-') return false;
    if (peerId.length > 7 && peerId[7] == '-') return true;
    if (peerId.length >= 3) {
      final prefix = peerId.substring(1, 3);
      if (['FG', 'LH', 'NE', 'KT', 'SP'].contains(prefix)) return true;
    }
    return false;
  }

  /// Shadow style: 第6字符 `-`，第1字符字母，第2字符数字或 `-`。
  static bool _isShadowStyle(String peerId) {
    if (peerId.length < 6) return false;
    if (peerId[5] != '-') return false;
    if (!_isLetter(peerId[0])) return false;
    if (!(_isDigit(peerId[1]) || peerId[1] == '-')) return false;
    return true;
  }

  /// Mainline style: 第3字符 `-`，第8字符 `-`，第5或第6字符 `-`。
  static bool _isMainlineStyle(String peerId) {
    if (peerId.length < 8) return false;
    return peerId[2] == '-' &&
        peerId[7] == '-' &&
        (peerId[4] == '-' || peerId[5] == '-');
  }

  /// Spoof 检测：以 `UDP0` 或 `HTTPBT` 结尾。
  static bool _isPossibleSpoofClient(String peerId) {
    return peerId.endsWith('UDP0') || peerId.endsWith('HTTPBT');
  }

  // ─── 客户端名查找 ────────────────────────────────────────────

  static String? _getAzStyleClientName(String peerId) {
    if (peerId.length < 3) return null;
    return _azStyleClients[peerId.substring(1, 3)];
  }

  static String? _getShadowStyleClientName(String peerId) {
    return _shadowStyleClients[peerId[0]];
  }

  static String? _getMainlineStyleClientName(String peerId) {
    return _mainlineStyleClients[peerId[0]];
  }

  static _SimpleClient? _getSimpleClient(String peerId) {
    for (final client in _simpleClients) {
      if (peerId.startsWith(client.id)) {
        return client;
      }
    }
    return null;
  }

  // ─── 版本号解码 ──────────────────────────────────────────────

  /// 解码 Az style 版本号。
  static String? _getAzStyleClientVersion(String client, String peerId) {
    if (peerId.length < 7) return null;
    final v = peerId.substring(3, 7);
    return _decodeAzVersion(client, v);
  }

  static String? _decodeAzVersion(String client, String v) {
    // 按客户端选择版本格式
    if (client == 'µTorrent' ||
        client == 'µTorrent Embedded' ||
        client == 'µTorrent Mac' ||
        client == 'µTorrent Web' ||
        client == 'BitTorrent') {
      return _verThreeDigitsPlusMnemonic(v);
    }
    if (client == 'qBittorrent' || client == 'Deluge') {
      return _verDeluge(v);
    }
    if (client == 'Transmission' || client == 'Xfplay') {
      return _verTransmission(v);
    }
    if (client == 'BitComet' || client == 'FlashGet') {
      return _verSkipFirstOneMajTwoMin(v);
    }
    if (client == 'libtorrent (Rasterbar)' ||
        client == 'libTorrent (Rakshasa)') {
      return _verThreeAlphanumericDigits(v);
    }
    if (client == 'KTorrent') {
      return _verKTorrent(v);
    }
    if (client == 'Vuze' ||
        client == 'Ares' ||
        client == 'BTG' ||
        client == 'OneSwarm' ||
        client == 'GS Torrent' ||
        client == 'Zona') {
      return _verFourDigits(v);
    }
    if (client == 'CTorrent' || client == 'Enhanced CTorrent') {
      return _verTwoMajTwoMin(v);
    }
    if (client == 'Lphant' || client == 'BitPump') {
      return _verTwoMajTwoMin(v);
    }
    if (client == 'Halite' ||
        client == 'linkage' ||
        client == 'Electric Sheep' ||
        client == 'MooPolice' ||
        client == 'BT Next Evolution' ||
        client == 'BitSpirit' ||
        client == 'TuoTu' ||
        client == 'Ares') {
      return _verThreeDigits(v);
    }
    if (client == 'SymTorrent') {
      return '${v[1]}.${v[2]}${v[3]}';
    }
    if (client == 'BitBuddy') {
      return '1.${v[2]}${v[3]}';
    }
    if (client == 'CTorrent') {
      return '1.${v[1]}.${v[2]}${v[3]}';
    }
    // 默认四段式
    return _verFourDigits(v);
  }

  /// "1.2.3"
  static String _verThreeDigits(String v) {
    return '${v[0]}.${v[1]}.${v[2]}';
  }

  /// "1.2.3.4"
  static String _verFourDigits(String v) {
    return '${v[0]}.${v[1]}.${v[2]}.${v[3]}';
  }

  /// "1.2.3 Beta/Alpha"
  static String _verThreeDigitsPlusMnemonic(String v) {
    var mnemonic = '';
    if (v[3] == 'B') {
      mnemonic = ' Beta';
    } else if (v[3] == 'A') {
      mnemonic = ' Alpha';
    }
    return '${v[0]}.${v[1]}.${v[2]}$mnemonic';
  }

  /// Deluge: "1.2.3" 或 "1.2.14"（字母时 A=0 B=1...E=4）
  static String _verDeluge(String v) {
    final alphabet = 'ABCDE';
    final idx = alphabet.indexOf(v[2]);
    if (idx >= 0) {
      return '${v[0]}.${v[1]}.${1 + idx}';
    }
    return '${v[0]}.${v[1]}.${v[2]}';
  }

  /// Transmission: "1.234" 或 "0.12"
  static String _verTransmission(String v) {
    if (v[0] == '0' && v[1] == '0' && v[2] == '0') {
      return '0.${v[3]}';
    }
    if (v[0] == '0' && v[1] == '0') {
      return '0.${v[2]}${v[3]}';
    }
    final suffix = (v[3] == 'Z' || v[3] == 'X') ? '+' : '';
    return '${v[0]}.${v[1]}${v[2]}$suffix';
  }

  /// BitComet/FlashGet: 跳过第1位，"2.34"
  static String _verSkipFirstOneMajTwoMin(String v) {
    return '${v[1]}.${v[2]}${v[3]}';
  }

  /// "12.34"
  static String _verTwoMajTwoMin(String v) {
    return '${v[0]}${v[1]}.${v[2]}${v[3]}';
  }

  /// "2.33.4"
  static String _verThreeAlphanumericDigits(String v) {
    return '${v[0]}.${v[1]}${v[2]}.${v[3]}';
  }

  /// KTorrent: "1.2.3.4"（简化）
  static String _verKTorrent(String v) {
    return '${v[0]}.${v[1]}.${v[2]}.${v[3]}';
  }

  // ─── 特殊客户端解码 ──────────────────────────────────────────

  static PeerIdInfo? _decodeBitSpiritClient(String peerId, List<int> buffer) {
    if (peerId.length < 4) return null;
    if (peerId.substring(2, 4) != 'BS') return null;
    var version = '${buffer[1]}';
    if (version == '0') version = '1';
    return PeerIdInfo(client: 'BitSpirit', version: version);
  }

  static PeerIdInfo? _decodeBitCometClient(String peerId, List<int> buffer) {
    if (peerId.length < 6) return null;
    String modName;
    if (peerId.startsWith('exbc')) {
      modName = '';
    } else if (peerId.startsWith('FUTB')) {
      modName = ' (Solidox Mod)';
    } else if (peerId.startsWith('xUTB')) {
      modName = ' (Mod 2)';
    } else {
      return null;
    }
    final isBitlord = peerId.length >= 10 && peerId.substring(6, 10) == 'LORD';
    final clientName = isBitlord ? 'BitLord' : 'BitComet';
    final majVersion = _decodeNumericByte(buffer[4]);
    final minVersionLength = (isBitlord && majVersion != '0') ? 1 : 2;
    final minVersion = _decodeNumericBytePadded(buffer[5], minVersionLength);
    return PeerIdInfo(
      client: '$clientName$modName',
      version: '$majVersion.$minVersion',
    );
  }

  static PeerIdInfo? _identifyAwkwardClient(
      String peerId, List<int> buffer) {
    var firstNonZeroIndex = 20;
    for (var i = 0; i < 20; i++) {
      if (buffer[i] > 0) {
        firstNonZeroIndex = i;
        break;
      }
    }

    // Shareaza
    if (firstNonZeroIndex == 0) {
      var isShareaza = true;
      for (var i = 0; i < 16; i++) {
        if (buffer[i] == 0) {
          isShareaza = false;
          break;
        }
      }
      if (isShareaza) {
        for (var i = 16; i < 20; i++) {
          if (buffer[i] != (buffer[i % 16] ^ buffer[15 - (i % 16)])) {
            isShareaza = false;
            break;
          }
        }
        if (isShareaza) return const PeerIdInfo(client: 'Shareaza');
      }
    }

    if (firstNonZeroIndex == 9 &&
        buffer[9] == 3 &&
        buffer[10] == 3 &&
        buffer[11] == 3) {
      return const PeerIdInfo(client: 'I2PSnark');
    }

    if (firstNonZeroIndex == 12 && buffer[12] == 97 && buffer[13] == 97) {
      return const PeerIdInfo(client: 'Experimental', version: '3.2.1b2');
    }

    if (firstNonZeroIndex == 12 && buffer[12] == 0 && buffer[13] == 0) {
      return const PeerIdInfo(client: 'Experimental', version: '3.1');
    }

    if (firstNonZeroIndex == 12) {
      return const PeerIdInfo(client: 'Mainline');
    }

    return null;
  }

  // ─── 工具函数 ────────────────────────────────────────────────

  /// 手动解码 URL 编码字符串为 Latin-1 字符串。
  ///
  /// 与 JavaScript `decodeURIComponent` 行为一致：
  /// `%XX` 解码为 code unit 0x00-0xFF，非编码字符原样保留。
  /// 不要求输入是合法 UTF-8，适合 BT peerId 这类二进制标识。
  static String _decodePercentEncoded(String input) {
    final buffer = StringBuffer();
    var i = 0;
    while (i < input.length) {
      if (input[i] == '%' && i + 2 < input.length) {
        final hex = input.substring(i + 1, i + 3);
        final codeUnit = int.tryParse(hex, radix: 16);
        if (codeUnit != null) {
          buffer.writeCharCode(codeUnit);
          i += 3;
          continue;
        }
      }
      buffer.write(input[i]);
      i++;
    }
    return buffer.toString();
  }

  /// 将字符串转为 UTF-8 字节列表。
  static List<int> _getUtf8Data(String s) {
    final buffer = <int>[];
    for (var i = 0; i < s.length; i++) {
      final ch = s.codeUnitAt(i);
      if (ch < 128) {
        buffer.add(ch);
      } else if (ch < 2048) {
        buffer.add((ch >> 6) | 192);
        buffer.add((ch & 63) | 128);
      } else {
        buffer.add((ch >> 12) | 224);
        buffer.add(((ch >> 6) & 63) | 128);
        buffer.add((ch & 63) | 128);
      }
    }
    return buffer;
  }

  static bool _isDigit(String s) {
    final code = s.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39; // '0'..'9'
  }

  static bool _isLetter(String s) {
    final code = s.toLowerCase().codeUnitAt(0);
    return code >= 0x61 && code <= 0x7A; // 'a'..'z'
  }

  static String _decodeNumericByte(int b) {
    return '${b & 0xff}';
  }

  static String _decodeNumericBytePadded(int b, int minDigits) {
    final result = '${b & 0xff}';
    if (result.length >= minDigits) return result;
    return '0' * (minDigits - result.length) + result;
  }
}

/// PeerId 解析结果。
class PeerIdInfo {
  const PeerIdInfo({required this.client, this.version});

  final String client;
  final String? version;

  /// 格式化显示：有版本时 "Client Version"，否则 "Client"。
  String get display {
    if (version != null && version!.isNotEmpty) {
      return '$client $version';
    }
    return client;
  }

  @override
  String toString() => display;
}

class _SimpleClient {
  const _SimpleClient(this.client, this.version, this.id);

  final String client;
  final String? version;
  final String id;
}

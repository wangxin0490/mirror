import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/utils/media_url.dart';

void main() {
  test('dedupeCoverUrls merges gallery and cover_image_url without duplicates', () {
    const gallery = ['public/feed/50_736b4838.jpg', 'public/feed/50_other.jpg'];
    const apiCover = 'https://docs.einrkv.com/public/feed/50_736b4838.jpg';

    expect(dedupeCoverUrls(gallery, apiCover), gallery);
    expect(dedupeCoverUrls(const [], apiCover), [apiCover]);
    expect(dedupeCoverUrls(gallery, ''), gallery);
  });
}

bool isCloudflareChallengePage(String html) {
  return html.contains('Just a moment') ||
      html.contains('challenges.cloudflare.com') ||
      html.contains('cf-chl-opt') ||
      html.contains('cdn-cgi/challenge-platform');
}

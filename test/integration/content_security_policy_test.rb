require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "responses carry a nonce-gated policy" do
    get root_path

    assert_response :success
    policy = response.headers["Content-Security-Policy"]
    assert policy, "expected a Content-Security-Policy header"

    assert_includes policy, "default-src 'self'"
    assert_includes policy, "object-src 'none'"
    assert_includes policy, "script-src 'self' https://plausible.io 'nonce-"
    assert_includes policy, "style-src-attr 'unsafe-inline'"
    assert_includes policy, "frame-ancestors 'none'"
    assert_no_match(/unsafe-eval/, policy)
    assert_no_match(/script-src[^;]*'unsafe-inline'/, policy)
  end

  test "inline analytics and importmap scripts carry the request nonce" do
    get root_path

    nonce = response.body[/<script nonce="([^"]+)"/, 1]
    assert nonce.present?, "expected an inline script to carry a nonce"
    assert_includes response.headers["Content-Security-Policy"], "'nonce-#{nonce}'"
    assert_match(/<script type="importmap"[^>]*nonce="#{Regexp.escape(nonce)}"/, response.body)
  end

  test "no inline handler, javascript URL, or local style attribute resists the policy" do
    lyric = Lyric.create!(lyrics: "A line")
    [ root_path, print_lyrics_on_one_page_path, lyric_path(lyric) ].each do |path|
      get path

      assert_no_match(/\son[a-z]+=/i, response.body, "#{path} has an inline event handler")
      assert_no_match(/javascript:/i, response.body, "#{path} has a javascript: URL")
      assert_no_match(/\sstyle=/i, response.body, "#{path} has a style attribute")
    end
  end

  test "every executable inline script carries the nonce and external scripts are allowlisted" do
    get root_path

    nonce = response.body[/<script nonce="([^"]+)"/, 1]
    # Data blocks (importmap, JSON-LD) are not subject to script-src; executable
    # inline scripts (module or classic) must carry the nonce.
    executable = response.body.scan(/<script[^>]*>/).reject do |tag|
      tag.include?("src=") || tag.match?(/type="(?:application\/ld\+json|importmap)"/)
    end
    assert executable.any?, "expected executable inline scripts in the page"
    executable.each do |tag|
      assert_includes tag, %(nonce="#{nonce}"), "executable inline script missing nonce: #{tag}"
    end

    response.body.scan(/<script[^>]*\bsrc="([^"]+)"/).flatten.each do |src|
      assert_match(%r{\A(?:https://plausible\.io|/)}, src, "external script not allowlisted: #{src}")
    end
  end

  test "the nonce is per response" do
    get root_path
    first = response.body[/<script nonce="([^"]+)"/, 1]

    get root_path
    second = response.body[/<script nonce="([^"]+)"/, 1]

    assert first.present? && second.present?
    assert_not_equal first, second
  end

  test "saved lyric pages also carry the policy" do
    lyric = Lyric.create!(lyrics: "A line")

    get lyric_path(lyric)

    assert_response :success
    assert_includes response.headers["Content-Security-Policy"], "default-src 'self'"
  end
end

class Ikshvaku < Formula
  desc "Lightweight Python environment manager powered by uv"
  homepage "https://github.com/ashish-jha-73/IkshvakuPEM"
  url "https://github.com/ashish-jha-73/IkshvakuPEM/releases/download/v1.3.0/ikshvaku-1.3.0.tar.gz"
  sha256 "126dc6cdb8eec1bea4de2b3002de6c91cf58c1d34b7844514833a1c772db0c0a"
  license "MIT"
  version "1.3.0"

  def install
    (share/"ikshvaku").install "src/ikshvaku.sh"
    (share/"ikshvaku").install "src/completion.sh"
  end

  def caveats
    <<~EOS
      Add the following lines to your ~/.zshrc (macOS default) or ~/.bashrc:

        source #{HOMEBREW_PREFIX}/share/ikshvaku/ikshvaku.sh
        source #{HOMEBREW_PREFIX}/share/ikshvaku/completion.sh

      Environments install to ~/.Python-Env. uv is downloaded automatically
      on first use. Upgrade with: brew upgrade ikshvaku
    EOS
  end

  test do
    ENV["HOME"] = testpath
    assert_match "ikshvaku 1.3.0",
      shell_output("source #{share}/ikshvaku/ikshvaku.sh && ikshvaku --version")
  end
end

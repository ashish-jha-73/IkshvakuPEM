class IkshvakuPEM < Formula
  desc "Lightweight Python environment manager powered by uv"
  homepage "https://github.com/ashish-jha-73/IkshvakuPEM"
  url "https://github.com/ashish-jha-73/IkshvakuPEM/releases/download/v1.4.0/ikshvaku-1.4.0.tar.gz"
  sha256 "efc2571f05ab7ac3c3c3dc63c9bf6660dccd64c4a6d9e8ba1cdee48603e880fd"
  license "MIT"
  version "1.4.0"

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
      on first use. Upgrade with: brew upgrade ikshvakupem
    EOS
  end

  test do
    ENV["HOME"] = testpath
    assert_match "ikshvaku 1.4.0",
      shell_output("source #{share}/ikshvaku/ikshvaku.sh && ikshvaku --version")
  end
end

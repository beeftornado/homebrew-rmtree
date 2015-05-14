class BrewRmtree < Formula
  homepage "https://github.com/beeftornado/homebrew-rmtree"
  url "https://github.com/beeftornado/homebrew-rmtree.git"
  version "1.1"

  head "https://github.com/beeftornado/homebrew-rmtree.git"

  skip_clean "bin"

  def install
    bin.install "brew-rmtree.rb"
    (bin + "brew-rmtree.rb").chmod 0755
  end

  test do
    system "brew", "rmtree", "--help"
  end
end

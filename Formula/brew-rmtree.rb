require 'formula'

class BrewRmtree < Formula
  homepage 'https://github.com/beeftornado/homebrew-rmtree'
  url 'git://github.com/beeftornado/homebrew-rmtree.git'
  version '1.1'

  skip_clean 'bin'

  def install
    bin.install 'brew-rmtree.rb'
    (bin + 'brew-rmtree.rb').chmod 0755
  end
end

class BrewRmtree < Formula
    homepage "https://github.com/beeftornado/homebrew-rmtree"
    url "https://github.com/beeftornado/homebrew-rmtree.git", :tag => "2.2.4"
  
    head "https://github.com/beeftornado/homebrew-rmtree.git"

    def install
      bin.install "cmd/brew-rmtree.rb"
    end
    
    def caveats
        <<~EOS.undent
          You can uninstall this formula, as `brew tap beeftornado/brew-rmtree` is all that's
          needed to install Rmtree and keep it up to date.
        EOS
      end
  
    test do
      system "brew", "rmtree", "--help"
    end
end

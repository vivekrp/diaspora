#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require 'spec_helper'

describe StatusMessagesHelper do
  it "should not allow basic XSS/HTML" do
    make_links("<script>alert('XSS is evil')</script>").should == "&lt;script&gt;alert('XSS is evil')&lt;/script&gt;"
  end

  it "should recognize basic http links (1/3)" do
    proto="http"
    url="bugs.joindiaspora.com/issues/332"
    make_links(proto+"://"+url).should == "<a target=\"_blank\" href=\""+proto+"://"+url+"\">"+url+"</a>"
  end

  it "should recognize basic http links (2/3)" do
    proto="http"
    url="webmail.example.com?~()!*/"
    make_links(proto+"://"+url).should == "<a target=\"_blank\" href=\""+proto+"://"+url+"\">"+url+"</a>"
  end

  it "should recognize basic http links (3/3)" do
    proto="http"
    url="127.0.0.1:3000/users/sign_in"
    make_links(proto+"://"+url).should == "<a target=\"_blank\" href=\""+proto+"://"+url+"\">"+url+"</a>"
  end

  it "should recognize secure https links" do
    proto="https"
    url="127.0.0.1:3000/users/sign_in"
    make_links(proto+"://"+url).should == "<a target=\"_blank\" href=\""+proto+"://"+url+"\">"+url+"</a>"
  end

  it "should recognize youtube links" do
    proto="http"
    videoid = "0x__dDWdf23"
    url="www.youtube.com/watch?v="+videoid+"&a=GxdCwVVULXdvEBKmx_f5ywvZ0zZHHHDU&list=ML&playnext=1"
    title = "UP & down & UP & down &amp;"
    mock_http = mock("http")
    Net::HTTP.stub!(:new).with('gdata.youtube.com', 80).and_return(mock_http)
    mock_http.should_receive(:get).with('/feeds/api/videos/'+videoid+'?v=2', nil).and_return([nil, 'Foobar <title>'+title+'</title> hallo welt <asd><dasdd><a>dsd</a>'])
    res = make_links(proto+'://'+url)
    res.should == "<a onclick=\"openVideo('youtube.com', '"+videoid+"', this)\" href=\"#video\">Youtube: "+title+"</a>"
  end

  it "should recognize a bunch of different links" do
    message = "http:// Hello World, this is for www.joindiaspora.com and not for http://www.google.com though their Youtube service is neat, take http://www.youtube.com/watch?v=foobar or www.youtube.com/watch?foo=bar&v=BARFOO&whatever=related It is a good idea we finally have youtube, so enjoy this video http://www.youtube.com/watch?v=rickrolld"
    mock_http = mock("http")
    Net::HTTP.stub!(:new).with('gdata.youtube.com', 80).and_return(mock_http)
    mock_http.should_receive(:get).with('/feeds/api/videos/foobar?v=2', nil).and_return([nil, 'Foobar <title>F 007 - the bar is not enough</title> hallo welt <asd><dasdd><a>dsd</a>'])
    mock_http.should_receive(:get).with('/feeds/api/videos/BARFOO?v=2', nil).and_return([nil, 'Foobar <title>BAR is the new FOO</title> hallo welt <asd><dasdd><a>dsd</a>'])
    mock_http.should_receive(:get).with('/feeds/api/videos/rickrolld?v=2', nil).and_return([nil, 'Foobar <title>Never gonne give you up</title> hallo welt <asd><dasdd><a>dsd</a>'])
    res = make_links(message)
    res.should == "http:// Hello World, this is for <a target=\"_blank\" href=\"http://www.joindiaspora.com\">www.joindiaspora.com</a> and not for <a target=\"_blank\" href=\"http://www.google.com\">www.google.com</a> though their Youtube service is neat, take <a onclick=\"openVideo('youtube.com', 'foobar', this)\" href=\"#video\">Youtube: F 007 - the bar is not enough</a> or <a onclick=\"openVideo('youtube.com', 'BARFOO', this)\" href=\"#video\">Youtube: BAR is the new FOO</a> It is a good idea we finally have youtube, so enjoy this video <a onclick=\"openVideo('youtube.com', 'rickrolld', this)\" href=\"#video\">Youtube: Never gonne give you up</a>"
  end

  it "should recognize basic ftp links" do
    proto="ftp"
    url="ftp.uni-kl.de/CCC/26C3/mp4/26c3-3540-en-a_hackers_utopia.mp4"
    # I did not watch that one, but the title sounds nice :P
    make_links(proto+"://"+url).should == "<a target=\"_blank\" href=\""+proto+"://"+url+"\">"+url+"</a>"
  end

  it "should recognize www links" do
    url="www.joindiaspora.com"
    make_links(url).should == "<a target=\"_blank\" href=\"http://"+url+"\">"+url+"</a>"
  end

  describe "markdown" do
    describe "weak emphasis" do
      it "should be recognized (1/2)" do
        message = "*some text* some text *some text* some text"
        make_links(message).should == "<em>some text</em> some text <em>some text</em> some text"
      end

      it "should be recognized (2/2)" do
        message = "_some text_ some text _some text_ some text"
        make_links(message).should == "<em>some text</em> some text <em>some text</em> some text"
      end
    end

    describe "strong emphasis" do
      it "should be recognized (1/2)" do
        message = "**some text** some text **some text** some text"
        make_links(message).should == "<strong>some text</strong> some text <strong>some text</strong> some text"
      end

      it "should be recognized (2/2)" do
        message = "__some text__ some text __some text__ some text"
        make_links(message).should == "<strong>some text</strong> some text <strong>some text</strong> some text"
      end
    end

    describe "imbricated weak and strong emphasis" do
      it "should be rendered correctly" do
        message = "__this is _some_ text__"
        make_links(message).should == "<strong>this is <em>some</em> text</strong>"
        message = "*this is **some** text*"
        make_links(message).should == "<em>this is <strong>some</strong> text</em>"
        message = "___some text___"
        make_links(message).should == "<em><strong>some text</strong></em>"
      end
    end

    describe "links" do
      it "should be recognized without title attribute" do
        message = "[link text](http://someurl.com) [link text](http://someurl.com)"
        make_links(message).should == '<a href="http://someurl.com">link text</a> <a href="http://someurl.com">link text</a>'
      end

      it "should be recognized with title attribute" do
        message = '[link text](http://someurl.com "some title") [link text](http://someurl.com "some title")'
        make_links(message).should == '<a href="http://someurl.com" title="some title">link text</a> <a href="http://someurl.com" title="some title">link text</a>'
      end
    end

    it "should allow escaping" do
      message = '*some text* \\*some text* \\**some text* _some text_ \\_some text_ \\__some text_'
      make_links(message).should == "<em>some text</em> *some text<em> *</em>some text <em>some text</em> _some text<em> _</em>some text"
    end
  end

  
end

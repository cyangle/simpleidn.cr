# encoding: utf-8
require "../spec_helper"

describe "SimpleIDN.to_unicode_fqdn" do
  it "converts to unicode (keeping/adding dot)" do
    SimpleIDN.to_unicode_fqdn("xn--mnchen-3ya.de").should eq("münchen.de.")
    SimpleIDN.to_unicode_fqdn("xn--mnchen-3ya.de.").should eq("münchen.de.")
  end
end

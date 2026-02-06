# encoding: utf-8
require "../spec_helper"

describe "SimpleIDN.valid_fqdn?" do
  it "validates FQDN" do
    SimpleIDN.valid_fqdn?("example.com").should be_true
    SimpleIDN.valid_fqdn?("example.com.").should be_true
    SimpleIDN.valid_fqdn?("*._sip._tcp.example.com").should be_true
  end
end

# encoding: utf-8
require "../spec_helper"

describe "SimpleIDN.valid_dns_name?" do
  it "allows underscores and wildcards" do
    SimpleIDN.valid_dns_name?("_dmarc.example.com").should be_true
    SimpleIDN.valid_dns_name?("*.example.com").should be_true
  end

  it "allows trailing dot" do
    SimpleIDN.valid_dns_name?("example.com.").should be_true
  end
end

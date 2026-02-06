# encoding: utf-8
require "../spec_helper"

describe "SimpleIDN.to_ascii_fqdn" do
  it "appends trailing dot if missing" do
    SimpleIDN.to_ascii_fqdn("example.com").should eq("example.com.")
  end

  it "keeps trailing dot if present" do
    SimpleIDN.to_ascii_fqdn("example.com.").should eq("example.com.")
  end

  it "allows underscores" do
    SimpleIDN.to_ascii_fqdn("*._sip._tcp.example.com").should eq("*._sip._tcp.example.com.")
  end

  it "allows max length of 254 (including trailing dot)" do
    # 253 + 1 = 254
    label_63 = "a" * 63
    label_61 = "a" * 61
    hostname = "#{label_63}.#{label_63}.#{label_63}.#{label_61}"
    hostname.bytesize.should eq(253)
    SimpleIDN.to_ascii_fqdn(hostname).should eq("#{hostname}.")

    # Try 254 input (already has dot)
    hostname_dot = "#{hostname}."
    SimpleIDN.to_ascii_fqdn(hostname_dot).should eq(hostname_dot)
  end
end

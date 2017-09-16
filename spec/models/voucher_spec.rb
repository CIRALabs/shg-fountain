require 'rails_helper'

RSpec.describe Voucher, type: :model do
  fixtures :all

  describe "relationships" do
    it "should have an associated MASA" do
      v1 = vouchers(:voucher1)
      expect(v1.manufacturer).to be_present
    end
    it "should have an associated MASA" do
      v1 = vouchers(:voucher1)
      expect(v1.voucher_request).to be_present
    end
  end

  describe "receiving vouchers" do
    it "should create voucher object and place the signed data in it" do
      voucher_base64 = IO::read(File.join("spec","files","voucher_12ea91.pkcs"))
      voucher_binary = Base64.decode64(voucher_base64)

      v1 = Voucher.from_voucher(:pkcs7, voucher_binary)

      expect(v1.owner_cert.subject.to_s).to eq("/DC=ca/DC=sandelman/CN=localhost")
      expect(v1.device).to eq(nodes(:bulb1))
    end

    it "should get a voucher format error on empty voucher object" do
      voucher_base64 = IO::read(File.join("spec","files","voucher_EMPTY.pkcs"))
      voucher_binary = Base64.decode64(voucher_base64)

      expect {
        v1 = Voucher.from_voucher(:pkcs7, voucher_binary)
      }.to raise_exception(Voucher::VoucherFormatError)
    end
  end


end
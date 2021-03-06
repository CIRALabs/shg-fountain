def get_stub(url, result, ct)

  voucher_request = nil
  up = URI.parse(url)

  stub_request(:get, url).
    with(headers: {
           'Accept'          => '*/*',
           'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
           'User-Agent'      => 'Ruby'
         }).
    to_return(status: 200, body: lambda { |request|
                voucher_request = request.body
                result},
              headers: {
                'Content-Type'=> ct
              })

end

def mud1_stub(url, filename = nil)
  result = ""
  if filename
    result = File.read(filename)
  end

  get_stub(url, result, 'application/mud+json')
end

def mud1_stub_sig(url, filename = nil)
  result   = ""
  if filename
    result = File.read(filename)
  end

  get_stub(url, result, 'application/pkcs7-signature')
end

def toaster_mud
  mud_file = "spec/files/mud/toaster_mud.json"
  mud_url  = "http://example.com/mud/toaster_mud.json"
  mud1_stub(mud_url, mud_file)

  mud_sig_file = "spec/files/mud/toaster_mud.json.sig"
  mud_sig_url  = "http://example.com/mud/toaster_mud.json.sig"
  mud1_stub_sig(mud_sig_url, mud_sig_file)

  mud_url
end

def mwave_mud
  mud_file = "spec/files/mud/mwave_mud.json"
  mud_url  = "http://example.com/mud/mwave_mud.json"
  mud1_stub(mud_url, mud_file)

  mud_sig_file = "spec/files/mud/mwave_mud.json.sig"
  # still toaster, because that's where the signature points
  mud_sig_url  = "http://example.com/mud/toaster_mud.json.sig"
  mud1_stub_sig(mud_sig_url, mud_sig_file)

  mud_url
end

def fridge_404_mud
  voucher_request = nil

  mud_file = "/dev/null"
  mud_url  = "http://example.com/mud/fridge_404_mud.json"

  stub_request(:get, mud_url).
    with(headers: {
           'Accept'          => '*/*',
           'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
           'User-Agent'      => 'Ruby'
         }).
    to_return(status: 404, body: "")

  mud_url
end

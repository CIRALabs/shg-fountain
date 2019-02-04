# -*- ruby -*-

namespace :fountain do

  # really only used in testing: this should be corporate CA, or Verisign, etc.
  desc "Create initial self-signed CA certificate for Registrar"
  task :s1_registrar_ca => :environment do
    curve = FountainKeys.ca.curve

    certdir = Rails.root.join('db').join('cert')
    FileUtils.mkpath(certdir)

    ownercaprivkey=certdir.join("ownerca_#{curve}.key")
    if File.exists?(ownercaprivkey)
      root_key = OpenSSL::PKey.read(File.open(ownercaprivkey))
    else
      # the CA's public/private key - 3*1024 + 8
      root_key = OpenSSL::PKey::EC.new(curve)
      root_key.generate_key
      File.open(ownercaprivkey, "w") do |f| f.write root_key.to_pem end
    end

    root_ca  = OpenSSL::X509::Certificate.new
    # cf. RFC 5280 - to make it a "v3" certificate
    root_ca.version = 2
    root_ca.serial  = FountainKeys.ca.serial
    hostname        = SystemVariable.string(:hostname).chomp
    root_ca.subject = OpenSSL::X509::Name.parse "/DC=ca/DC=sandelman/CN=#{hostname} Unstrung Fountain Root CA"

    # root CA's are "self-signed"
    root_ca.issuer = root_ca.subject
    #root_ca.public_key = root_key.public_key
    root_ca.public_key = root_key
    root_ca.not_before = Time.now

    # 2 years validity
    root_ca.not_after = root_ca.not_before + 2 * 365 * 24 * 60 * 60

    # Extension Factory
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = root_ca
    ef.issuer_certificate  = root_ca
    root_ca.add_extension(ef.create_extension("basicConstraints","CA:TRUE",true))
    root_ca.add_extension(ef.create_extension("keyUsage","keyCertSign, cRLSign", true))
    root_ca.add_extension(ef.create_extension("subjectKeyIdentifier","hash",false))
    root_ca.add_extension(ef.create_extension("authorityKeyIdentifier","keyid:always",false))
    root_ca.sign(root_key, OpenSSL::Digest::SHA256.new)

    File.open(certdir.join("ownerca_#{curve}.crt"),'w') do |f|
      f.write root_ca.to_pem
    end
  end

  desc "Create a certificate for the Registration Authority to own devices with"
  task :s2_create_registrar => :environment do

    curve = FountainKeys.ca.client_curve

    certdir = Rails.root.join('db').join('cert')
    FileUtils.mkpath(certdir)

    jrcprivkey=certdir.join("jrc_#{curve}.key")
    if File.exists?(jrcprivkey)
      jrc_key = OpenSSL::PKey.read(File.open(jrcprivkey))
    else
      # the JRC's public/private key - 3*1024 + 8
      jrc_key = OpenSSL::PKey::EC.new(curve)
      jrc_key.generate_key
      File.open(jrcprivkey, "w") do |f| f.write jrc_key.to_pem end
    end

    jrc_crt  = OpenSSL::X509::Certificate.new
    # cf. RFC 5280 - to make it a "v3" certificate
    jrc_crt.version = 2
    jrc_crt.serial = FountainKeys.ca.serial
    dnprefix = SystemVariable.string(:dnprefix) || "/DC=ca/DC=sandelman"
    dn = sprintf("%s/CN=%s", dnprefix, SystemVariable.string(:hostname).chomp)
    jrc_crt.subject = OpenSSL::X509::Name.parse dn

    root_ca = FountainKeys.ca.rootkey
    # jrc is signed by root_ca
    jrc_crt.issuer = root_ca.subject
    #root_ca.public_key = root_key.public_key
    jrc_crt.public_key = jrc_key
    jrc_crt.not_before = Time.now

    # 2 years validity
    jrc_crt.not_after = jrc_crt.not_before + 2 * 365 * 24 * 60 * 60

    # Extension Factory
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = jrc_crt
    ef.issuer_certificate  = root_ca
    ef.config = OpenSSL::Config.load("registrar-ssl.cnf")
    jrc_crt.add_extension(ef.create_extension("basicConstraints","CA:FALSE",true))

    begin
      n = ef.create_extension("extendedKeyUsage","cmcRA:TRUE",true)
      jrc_crt.add_extension(n)
    rescue OpenSSL::X509::ExtensionError
      puts "Can not setup cmcRA extension, as openssl not patched, continuing anyway..."
    end
    jrc_crt.sign(FountainKeys.ca.rootprivkey, OpenSSL::Digest::SHA256.new)

    File.open(certdir.join("jrc_#{curve}.crt"),'w') do |f|
      f.write jrc_crt.to_pem
    end
  end

  desc "Create a keypair for the domain owner to own devices with"
  task :s4_domain_authority => :environment do

    curve = FountainKeys.ca.client_curve

    certdir = Rails.root.join('db').join('cert')
    FileUtils.mkpath(certdir)

    domainprivkey=certdir.join("domain_#{curve}.key")
    if File.exists?(domainprivkey)
      domain_key = OpenSSL::PKey.read(File.open(domainprivkey))
    else
      # the JRC's public/private key - 3*1024 + 8
      domain_key = OpenSSL::PKey::EC.new(curve)
      domain_key.generate_key
      File.open(domainprivkey, "w") do |f| f.write domain_key.to_pem end
    end

    domain_crt  = OpenSSL::X509::Certificate.new
    # cf. RFC 5280 - to make it a "v3" certificate
    domain_crt.version = 2
    domain_crt.serial = FountainKeys.ca.serial
    dnprefix = SystemVariable.string(:dnprefix) || "/DC=ca/DC=sandelman"
    dn = sprintf("%s/CN=%s domain authority", dnprefix, SystemVariable.string(:hostname).chomp)
    domain_crt.subject = OpenSSL::X509::Name.parse dn

    root_ca = FountainKeys.ca.rootkey
    # jrc is signed by root_ca
    domain_crt.issuer = root_ca.subject
    #root_ca.public_key = root_key.public_key
    domain_crt.public_key = domain_key
    domain_crt.not_before = Time.now

    # 1 year validity
    domain_crt.not_after = domain_crt.not_before + 1 * 365 * 24 * 60 * 60

    # Extension Factory
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = domain_crt
    ef.issuer_certificate  = root_ca
    #ef.config = OpenSSL::Config.load("registrar-ssl.cnf")
    domain_crt.add_extension(ef.create_extension("basicConstraints","CA:TRUE",true))

    domain_crt.sign(FountainKeys.ca.rootprivkey, OpenSSL::Digest::SHA256.new)

    File.open(certdir.join("domain_#{curve}.crt"),'w') do |f|
      f.write domain_crt.to_pem
    end
  end

  # utility used with testing to fill in issuer_* in manufacturers.yml
  desc "Read a certificate from CERT= and extract the base64 of the public_key to yaml"
  task :cert2pubkey => :environment do
    file = ENV['CERT']

    puts "# Reading certificate from #{file}"
    certio = IO::read(file)
    cert   = OpenSSL::X509::Certificate.new(certio)
    pubkey = cert.public_key.to_der
    manu = Hash.new
    manu["issuer_dn"] = cert.issuer.to_s
    manu["issuer_public_key"] = pubkey
    puts manu.to_yaml(:root => "manu")
  end


end

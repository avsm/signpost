require 'digest/sha1'

class KeyStore
  def initialize
    @local_keys = {}
    @remote_keys = {}
  end

  def key_for_remote_id id
    @remote_keys[id] ||= {:key => acquire_remote_key_for(id), :discard_at => discard_at}
    @remote_keys[id][:key]
  end

  def key_for_local_id id
    @local_keys[id] ||= {:key => gen_random_key, :discard_at => discard_at}
    @local_keys[id][:key]
  end

  private
  def gen_random_key
    # TODO: Generate real keys here...
    "rararandomkekekey#{rand(Time.now.to_i)}"
  end

  def discard_at
    Time.now.to_i + 60 * 60
  end

  def acquire_remote_key_for id
    # TODO:
    # * Get key for Id
    "rararandomkekekeyremote#{id}"
  end
end

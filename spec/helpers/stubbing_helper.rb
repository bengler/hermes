module StubbingHelper

  def stub_checkpoint_success!
    stub_request(:get, "http://example.org/api/checkpoint/v1/identities/me?").
      to_return(status: 200,
        body: '{"identity":{"id":2751025,"god":true,"created_at":"2012-10-23T16:27:45+02:00","realm":"test","provisional":false,"fingerprints":["some_checkpoint_god_session_for_test_realm"]},"accounts":["facebook"],"profile":{"provider":"facebook","nickname":"skogsmaskin","name":"Per-Kristian Nordnes","profile_url":null,"image_url":"http://graph.facebook.com/552821200/picture?type=square","description":null}}',
        headers: {})
  end

end
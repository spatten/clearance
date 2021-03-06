require 'test_helper'

class UserTest < ActiveSupport::TestCase

  should_not_allow_mass_assignment_of :email_confirmed,
    :salt, :encrypted_password, :remember_token

  # signing up

  context "When signing up" do
    should_validate_presence_of :email, :password
    should_allow_values_for     :email, "foo@example.com"
    should_not_allow_values_for :email, "foo"
    should_not_allow_values_for :email, "example.com"

    should "require password confirmation on create" do
      user = Factory.build(:user, :password              => 'blah',
                                  :password_confirmation => 'boogidy')
      assert ! user.save
      assert user.errors.on(:password)
    end

    should "require non blank password confirmation on create" do
      user = Factory.build(:user, :password              => 'blah',
                                  :password_confirmation => '')
      assert ! user.save
      assert user.errors.on(:password)
    end

    should "initialize salt" do
      assert_not_nil Factory(:user).salt
    end

    should "initialize confirmation token" do
      assert_not_nil Factory(:user).confirmation_token
    end

    context "encrypt password" do
      setup do
        @salt = "salt"
        @user = Factory.build(:user, :salt => @salt)
        def @user.initialize_salt; end
        @user.save!
        @password = @user.password

        @user.send(:encrypt, @password)
        @expected = Digest::SHA1.hexdigest("--#{@salt}--#{@password}--")
      end

      should "create an encrypted password using SHA1 encryption" do
        assert_equal @expected, @user.encrypted_password
      end
    end

    should "store email in exact case" do
      user = Factory(:user, :email => "John.Doe@example.com")
      assert_equal "John.Doe@example.com", user.email
    end
  end

  context "When multiple users have signed up" do
    setup { @user = Factory(:user) }
    should_validate_uniqueness_of :email
  end

  # confirming email

  context "A user without email confirmation" do
    setup do
      @user = Factory(:user)
      assert ! @user.email_confirmed?
    end

    context "after #confirm_email!" do
      setup do
        assert @user.confirm_email!
        @user.reload
      end

      should "have confirmed their email" do
        assert @user.email_confirmed?
      end

      should "reset confirmation token" do
        assert_nil @user.confirmation_token
      end
    end
  end

  # authenticating

  context "A user" do
    setup do
      @user     = Factory(:user)
      @password = @user.password
    end

    should "authenticate with good credentials" do
      assert ::User.authenticate(@user.email, @password)
      assert @user.authenticated?(@password)
    end

    should "not authenticate with bad credentials" do
      assert ! ::User.authenticate(@user.email, 'bad_password')
      assert ! @user.authenticated?('bad_password')
    end
  end

  # remember me

  context "When authenticating with remember_me!" do
    setup do
      @user  = Factory(:email_confirmed_user)
      assert_nil @user.remember_token
      @user.remember_me!
    end

    should "set the remember token" do
      assert_not_nil @user.remember_token
    end
  end

  # updating password

  context "An email confirmed user" do
    setup do
      @user = Factory(:email_confirmed_user)
      @old_encrypted_password = @user.encrypted_password
    end

    context "who updates password with confirmation" do
      setup do
        @user.update_password("new_password", "new_password")
      end

      should "change encrypted password" do
        assert_not_equal @user.encrypted_password,
                         @old_encrypted_password
      end
    end
  end

  should "not generate the same remember token for users with the same password at the same time" do
    password    = 'secret'
    first_user  = Factory(:email_confirmed_user,
                          :password              => password,
                          :password_confirmation => password)
    second_user = Factory(:email_confirmed_user,
                          :password              => password,
                          :password_confirmation => password)

    Time.stubs(:now => Time.now)
    first_user.remember_me!
    second_user.remember_me!

    assert_not_equal first_user.remember_token, second_user.remember_token
  end

  # recovering forgotten password

  context "An email confirmed user" do
    setup do
      @user = Factory(:email_confirmed_user)
      @old_encrypted_password = @user.encrypted_password
      @user.confirm_email!
    end

    context "who requests password reminder" do
      setup do
        assert_nil @user.confirmation_token
        @user.forgot_password!
      end

      should "generate confirmation token" do
        assert_not_nil @user.confirmation_token
      end

      context "and then updates password" do
        context 'with confirmation' do
          setup do
            @user.update_password("new_password", "new_password")
          end

          should "change encrypted password" do
            assert_not_equal @user.encrypted_password,
                             @old_encrypted_password
          end

          should "clear confirmation token" do
            assert_nil @user.confirmation_token
          end
        end

        context 'without confirmation' do
          setup do
            @user.update_password("new_password", "")
          end

          should "not change encrypted password" do
            assert_equal @user.encrypted_password,
                         @old_encrypted_password
          end

          should "not clear confirmation token" do
            assert_not_nil @user.confirmation_token
          end
        end
      end
    end

  end

end

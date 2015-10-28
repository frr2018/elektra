require 'spec_helper'

describe Core::ApplicationController, type: :controller do
  
  controller do
    def index
      render html: '<h1>test</h1>'
    end
  end

  include AuthenticationStub

  before :each do
    stub_authentication

    admin_identity_driver = double('admin_identity_service_driver').as_null_object
    allow_any_instance_of(DomainModel::AdminIdentityService).to receive(:get_driver).and_return(admin_identity_driver)

    allow(controller).to receive(:_routes).and_return(@routes)
  end

  context "non modal request" do

    describe "GET 'index'" do
      
      it "returns http success" do
        get :index
        expect(response).to render_template(:layout => "layouts/core/application")
      end
    end
  end
  
  context "modal request" do

    describe "GET 'index'" do
      it "returns http success" do
        xhr :get, :index, modal: true
        expect(controller.modal?).to eq(true)
      end
    end
  end

end

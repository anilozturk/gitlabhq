require 'spec_helper'

describe Admin::ImpersonationsController do
  let(:impersonator) { create(:admin) }
  let(:user) { create(:user) }

  describe "DELETE destroy" do
    context "when not signed in" do
      it "redirects to the sign in page" do
        delete :destroy

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before do
        sign_in(user)
      end

      context "when not impersonating" do
        it "responds with status 404" do
          delete :destroy

          expect(response).to have_http_status(404)
        end

        it "doesn't sign us in" do
          delete :destroy

          expect(warden.user).to eq(user)
        end
      end

      context "when impersonating" do
        before do
          session[:impersonator_id] = impersonator.id
        end

        context "when the impersonator is not admin (anymore)" do
          before do
            impersonator.admin = false
            impersonator.save
          end

          it "responds with status 404" do
            delete :destroy

            expect(response).to have_http_status(404)
          end

          it "doesn't sign us in as the impersonator" do
            delete :destroy

            expect(warden.user).to eq(user)
          end
        end

        context "when the impersonator is admin" do
          context "when the impersonator is blocked" do
            before do
              impersonator.block!
            end

            it "responds with status 404" do
              delete :destroy

              expect(response).to have_http_status(404)
            end

            it "doesn't sign us in as the impersonator" do
              delete :destroy

              expect(warden.user).to eq(user)
            end
          end

          context "when the impersonator is not blocked" do
            it "redirects to the impersonated user's page" do
              expect(Gitlab::AppLogger).to receive(:info).with("User #{impersonator.username} has stopped impersonating #{user.username}").and_call_original

              delete :destroy

              expect(response).to redirect_to(admin_user_path(user))
            end

            it "signs us in as the impersonator" do
              delete :destroy

              expect(warden.user).to eq(impersonator)
            end
          end
        end
      end
    end
  end
end

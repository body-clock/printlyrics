# The songbook offer's own moment: the visitor said not now.
#
# The offer is rendered by the server from the visit it holds, so the answer has
# to be held there too — a flag only one tab knew about would let the next page
# render it again. Both answers end the offer for the rest of the visit;
# accepting it is the creation itself, which lands on the set.
class SongbookOffersController < ApplicationController
  def destroy
    visit.answer_offer!
    redirect_back_or_to root_path, allow_other_host: false
  end
end

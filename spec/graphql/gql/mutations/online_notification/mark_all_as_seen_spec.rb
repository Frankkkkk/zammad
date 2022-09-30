# Copyright (C) 2012-2022 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe Gql::Mutations::OnlineNotification::MarkAllAsSeen, type: :graphql, authenticated_as: :user do
  let(:user)                      { create(:agent) }
  let(:notification_a)            { create(:online_notification, user: user) }
  let(:notification_b)            { create(:online_notification, user: user) }
  let(:notification_c)            { create(:online_notification, user: user) }
  let(:another_user_notification) { create(:online_notification, user: create(:user)) }

  let(:query) do
    <<~QUERY
      mutation onlineNotificationMarkAllAsSeen($onlineNotificationIds: [ID!]!) {
        onlineNotificationMarkAllAsSeen(onlineNotificationIds: $onlineNotificationIds) {
          onlineNotifications {
            id
          }
        }
      }
    QUERY
  end

  let(:variables) { { onlineNotificationIds: notifications_to_mark.map(&:to_gid_param) } }

  before do
    user.groups << Ticket.first.group
    gql.execute(query, variables: variables)
  end

  context 'when marking multiple notifications' do
    let(:notifications_to_mark) { [notification_a, notification_b] }

    it 'marks selected notifications as seen' do
      expect([notification_a.reload, notification_b.reload])
        .to contain_exactly(
          have_attributes(id: notification_a.id, seen: true),
          have_attributes(id: notification_b.id, seen: true)
        )
    end

    it 'does not touch other notifications' do
      expect(notification_c.reload).to have_attributes(seen: false)
    end

    it 'returns touched notifications' do
      expect(gql.result.data['onlineNotifications'])
        .to contain_exactly(
          include('id' => notification_a.to_gid_param),
          include('id' => notification_b.to_gid_param)
        )
    end
  end

  context 'when marking another user notifications' do
    let(:notifications_to_mark) { [another_user_notification] }

    it 'does not touch inaccessible notification' do
      expect(another_user_notification.reload).to have_attributes(seen: false)
    end

    it 'report as error' do
      expect(gql.result.error).to be_present
    end
  end

  context 'when marking non-existant user notifications' do
    let(:variables) { { ids: ['asd'] } }

    it 'report as error' do
      expect(gql.result.error).to be_present
    end
  end
end

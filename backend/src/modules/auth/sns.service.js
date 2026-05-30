import { PublishCommand, SNSClient } from '@aws-sdk/client-sns';

import { env } from '../../config/env.js';
import { ApiError } from '../../utils/ApiError.js';

let snsClient;
let testPublisher;

export function setSnsPublisherForTests(publisher) {
  testPublisher = publisher;
}

function smsAttributes() {
  const attributes = {
    'AWS.SNS.SMS.SMSType': {
      DataType: 'String',
      StringValue: 'Transactional',
    },
  };
  if (env.awsSnsSmsSenderId) {
    attributes['AWS.SNS.SMS.SenderID'] = {
      DataType: 'String',
      StringValue: env.awsSnsSmsSenderId,
    };
  }
  return attributes;
}

function client() {
  if (snsClient) {
    return snsClient;
  }
  snsClient = new SNSClient({
    region: env.awsRegion,
    credentials: {
      accessKeyId: env.awsAccessKeyId,
      secretAccessKey: env.awsSecretAccessKey,
      ...(env.awsSessionToken ? { sessionToken: env.awsSessionToken } : {}),
    },
  });
  return snsClient;
}

export async function sendSignupOtpSms(phone, otp) {
  if (testPublisher) {
    await testPublisher({ phone, otp });
    return;
  }
  if (!env.hasAwsSnsConfig) {
    throw new ApiError(503, 'OTP delivery is not configured.');
  }

  try {
    await client().send(
      new PublishCommand({
        PhoneNumber: `+977${phone}`,
        Message: `Your Sajha Kharcha signup OTP is ${otp}. It expires in ${env.otpTtlMinutes} minutes.`,
        MessageAttributes: smsAttributes(),
      }),
    );
  } catch (error) {
    throw new ApiError(502, 'Unable to send OTP right now.', error);
  }
}

const amqp = require('amqplib');
const config = require('./config');

let connection;
let channel;
let connecting;

async function publishSubmission(submission) {
  const activeChannel = await getChannel();
  const payload = Buffer.from(JSON.stringify(submission));
  const accepted = activeChannel.sendToQueue(config.rabbitmq.queue, payload, {
    contentType: 'application/json',
    deliveryMode: 2
  });

  if (!accepted) {
    await new Promise((resolve) => activeChannel.once('drain', resolve));
  }

  await activeChannel.waitForConfirms();
}

async function getChannel() {
  if (channel) {
    return channel;
  }

  if (!connecting) {
    connecting = connect();
  }

  try {
    await connecting;
  } finally {
    connecting = undefined;
  }

  return channel;
}

async function connect() {
  connection = await amqp.connect(buildRabbitUrl());
  connection.on('close', resetConnection);
  connection.on('error', (error) => {
    console.error('RabbitMQ connection error:', error.message);
  });

  channel = await connection.createConfirmChannel();
  channel.on('close', () => {
    channel = undefined;
  });
  channel.on('error', (error) => {
    console.error('RabbitMQ channel error:', error.message);
  });

  await channel.assertQueue(config.rabbitmq.queue, {
    durable: true
  });
}

function buildRabbitUrl() {
  const user = encodeURIComponent(config.rabbitmq.user);
  const password = encodeURIComponent(config.rabbitmq.password);

  return `amqp://${user}:${password}@${config.rabbitmq.host}:${config.rabbitmq.port}`;
}

function resetConnection() {
  connection = undefined;
  channel = undefined;
  connecting = undefined;
}

async function close() {
  const activeChannel = channel;
  const activeConnection = connection;

  resetConnection();

  if (activeChannel) {
    await activeChannel.close();
  }

  if (activeConnection) {
    await activeConnection.close();
  }
}

module.exports = {
  close,
  getChannel,
  publishSubmission
};
